#!/usr/bin/env bash
set -euo pipefail

container_name='framework-usage-sql-2022'
work_root="${RUNNER_TEMP}/framework-usage-runtime-diagnostic"
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

docker pull --quiet mcr.microsoft.com/mssql/server:2022-latest >/dev/null
docker run -d --name "${container_name}" --memory 4g --cpus 2 \
  -e ACCEPT_EULA=Y -e MSSQL_PID=Developer \
  -e MSSQL_COLLATION=SQL_Latin1_General_CP1_CS_AS \
  -e MSSQL_SA_PASSWORD="${credential}" \
  -v "${work_root}/repository:/workspace:ro" \
  mcr.microsoft.com/mssql/server:2022-latest >/dev/null

ready=0
for attempt in $(seq 1 90); do
  if docker exec -e SQLCMDPASSWORD="${credential}" "${container_name}" \
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -l 10 -b \
    -Q 'SET NOCOUNT ON; SELECT 1;' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
if [ "${ready}" -ne 1 ]; then
  docker logs --tail 100 "${container_name}"
  exit 1
fi

docker exec -e SQLCMDPASSWORD="${credential}" "${container_name}" \
  /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -b \
  -Q "CREATE DATABASE [FrameworkContract] COLLATE SQL_Latin1_General_CP1_CS_AS; ALTER DATABASE [FrameworkContract] SET COMPATIBILITY_LEVEL = 160; ALTER DATABASE [FrameworkContract] SET QUERY_STORE = ON; ALTER DATABASE [FrameworkContract] SET QUERY_STORE (OPERATION_MODE = READ_WRITE);" >/dev/null

docker exec -e SQLCMDPASSWORD="${credential}" "${container_name}" bash -lc '
  cd /workspace/Code/Install
  exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d FrameworkContract -b -i Install_All.sql
' >"${work_root}/install.log" 2>&1 || {
  echo 'INSTALL_FAILURE_BEGIN'
  grep -E '^(Msg [0-9]+|HResult)|(_MISSING|_INVALID|_FAILED)( |$)' "${work_root}/install.log" | tail -n 120 || true
  echo 'INSTALL_FAILURE_END'
  exit 1
}

set +e
docker exec -e SQLCMDPASSWORD="${credential}" "${container_name}" bash -lc '
  cd /workspace/Code/Tests
  exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d FrameworkContract -b -i Run_Release_Gate.sql
' >"${work_root}/release.log" 2>&1
status=$?
set -e
if [ "${status}" -ne 0 ]; then
  echo 'RELEASE_GATE_FAILURE_BEGIN'
  grep -E '^(RELEASE_GATE [0-9]+/34|Msg [0-9]+|HResult)|FRAMEWORK_USAGE|(_MISSING|_INVALID|_FAILED)( |$)' "${work_root}/release.log" | tail -n 180 || true
  echo 'RELEASE_GATE_FAILURE_END'
  exit "${status}"
fi

grep -q 'FRAMEWORK_USAGE_RUNTIME_CONTRACT PASS' "${work_root}/release.log"
echo 'FRAMEWORK_USAGE_RUNTIME_DIAGNOSTIC PASS'
