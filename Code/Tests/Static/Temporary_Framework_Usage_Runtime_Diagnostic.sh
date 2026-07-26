#!/usr/bin/env bash
set -euo pipefail

: "${SQL_YEAR:?SQL_YEAR is required}"
: "${SQL_PRODUCT_MAJOR:?SQL_PRODUCT_MAJOR is required}"
: "${SQL_IMAGE:?SQL_IMAGE is required}"
: "${SQL_COMPATIBILITY:?SQL_COMPATIBILITY is required}"
: "${SQL_PERMISSION_TEST:?SQL_PERMISSION_TEST is required}"

container_name="framework-usage-sql-${SQL_YEAR}"
work_root="${RUNNER_TEMP}/framework-usage-${SQL_YEAR}"
credential="Synthet1c!$(openssl rand -hex 16)"
echo "::add-mask::${credential}"

cleanup() {
  docker rm -f "${container_name}" >/dev/null 2>&1 || true
  rm -rf "${work_root}"
}
trap cleanup EXIT

mkdir -p "${work_root}/repository"
git archive HEAD | tar -x -C "${work_root}/repository"
find "${work_root}/repository/Code" -type f -name '*.sql' -print0 \
  | xargs -0 sed -i 's/\[DeineDatenbank\]/[FrameworkContract]/g'

docker pull --quiet "${SQL_IMAGE}" >/dev/null
docker run -d --name "${container_name}" --memory 4g --cpus 2 \
  -e ACCEPT_EULA=Y -e MSSQL_PID=Developer \
  -e MSSQL_COLLATION=SQL_Latin1_General_CP1_CS_AS \
  -e MSSQL_SA_PASSWORD="${credential}" \
  -v "${work_root}/repository:/workspace:ro" \
  "${SQL_IMAGE}" >/dev/null

sqlcmd_query() {
  local query="$1"
  docker exec -e SQLCMDPASSWORD="${credential}" "${container_name}" bash -s -- "${query}" <<'INNER'
set -euo pipefail
query="$1"
if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
  exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -l 15 -b -Q "$query"
fi
exec /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -l 15 -b -Q "$query"
INNER
}

sqlcmd_file() {
  local file="$1"
  docker exec -e SQLCMDPASSWORD="${credential}" "${container_name}" bash -s -- "${file}" <<'INNER'
set -euo pipefail
file="$1"
if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then
  exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d FrameworkContract -b -i "$file"
fi
exec /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -d FrameworkContract -b -i "$file"
INNER
}

ready=0
for attempt in $(seq 1 90); do
  if sqlcmd_query 'SET NOCOUNT ON; SELECT 1;' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
if [ "${ready}" -ne 1 ]; then
  docker logs --tail 100 "${container_name}"
  exit 1
fi

sqlcmd_query "CREATE DATABASE [FrameworkContract] COLLATE SQL_Latin1_General_CP1_CS_AS; ALTER DATABASE [FrameworkContract] SET COMPATIBILITY_LEVEL = ${SQL_COMPATIBILITY}; ALTER DATABASE [FrameworkContract] SET QUERY_STORE = ON; ALTER DATABASE [FrameworkContract] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);" >/dev/null
sqlcmd_query "IF CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) <> ${SQL_PRODUCT_MAJOR} THROW 51000, 'UNEXPECTED_PRODUCT_MAJOR_VERSION', 1; IF CONVERT(sysname,SERVERPROPERTY('Collation')) <> N'SQL_Latin1_General_CP1_CS_AS' THROW 51000, 'UNEXPECTED_SERVER_COLLATION', 1; IF CONVERT(sysname,DATABASEPROPERTYEX(N'tempdb',N'Collation')) <> N'SQL_Latin1_General_CP1_CS_AS' THROW 51000, 'UNEXPECTED_TEMPDB_COLLATION', 1;" >/dev/null

set +e
sqlcmd_file /workspace/Code/Install/Install_All.sql >"${work_root}/install.log" 2>&1
install_status=$?
set -e
if [ "${install_status}" -ne 0 ]; then
  echo "SQL_${SQL_YEAR}_INSTALL_FAILURE_BEGIN"
  grep -E '^(Msg [0-9]+|HResult)|(_MISSING|_INVALID|_FAILED)( |$)' "${work_root}/install.log" | tail -n 160 || true
  echo "SQL_${SQL_YEAR}_INSTALL_FAILURE_END"
  exit "${install_status}"
fi

set +e
sqlcmd_file /workspace/Code/Tests/Run_Release_Gate.sql >"${work_root}/release.log" 2>&1
release_status=$?
set -e
if [ "${release_status}" -ne 0 ]; then
  echo "SQL_${SQL_YEAR}_RELEASE_FAILURE_BEGIN"
  grep -E '^(RELEASE_GATE [0-9]+/34|Msg [0-9]+|HResult)|FRAMEWORK_USAGE|(_MISSING|_INVALID|_FAILED)( |$)' "${work_root}/release.log" | tail -n 220 || true
  echo "SQL_${SQL_YEAR}_RELEASE_FAILURE_END"
  exit "${release_status}"
fi

grep -q 'FRAMEWORK_USAGE_RUNTIME_CONTRACT PASS' "${work_root}/release.log"

set +e
sqlcmd_file "/workspace/${SQL_PERMISSION_TEST}" >"${work_root}/permission.log" 2>&1
permission_status=$?
set -e
if [ "${permission_status}" -ne 0 ]; then
  echo "SQL_${SQL_YEAR}_PERMISSION_FAILURE_BEGIN"
  grep -E '^(Msg [0-9]+|HResult)|(_MISSING|_INVALID|_FAILED)( |$)|PERMISSION' "${work_root}/permission.log" | tail -n 160 || true
  echo "SQL_${SQL_YEAR}_PERMISSION_FAILURE_END"
  exit "${permission_status}"
fi

echo "FRAMEWORK_USAGE_SQL_${SQL_YEAR}_MATRIX PASS"
