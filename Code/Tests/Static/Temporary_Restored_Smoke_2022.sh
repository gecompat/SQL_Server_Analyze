#!/usr/bin/env bash
set -euo pipefail

work_root="${RUNNER_TEMP}/restored-smoke-diagnostic"
container='framework-restored-smoke-2022'
credential="Synthet1c!$(openssl rand -hex 16)"
echo "::add-mask::$credential"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true; rm -rf "$work_root"' EXIT

mkdir -p "$work_root/repository"
git archive HEAD | tar -x -C "$work_root/repository"
find "$work_root/repository/Code" -type f -name '*.sql' -print0 | xargs -0 sed -i 's/\[DeineDatenbank\]/[FrameworkContract]/g'

docker pull --quiet mcr.microsoft.com/mssql/server:2022-latest >/dev/null
ready=0
for container_attempt in 1 2 3; do
  docker rm -f "$container" >/dev/null 2>&1 || true
  docker run -d --name "$container" --memory 4g --cpus 2 \
    -e ACCEPT_EULA=Y -e MSSQL_PID=Developer \
    -e MSSQL_COLLATION=SQL_Latin1_General_CP1_CS_AS \
    -e MSSQL_SA_PASSWORD="$credential" \
    -v "$work_root/repository:/workspace:ro" \
    mcr.microsoft.com/mssql/server:2022-latest >/dev/null
  for attempt in $(seq 1 120); do
    if docker exec -e SQLCMDPASSWORD="$credential" "$container" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -l 15 -b -Q 'SET NOCOUNT ON; SELECT 1;' >/dev/null 2>&1; then ready=1; break; fi
    sleep 2
  done
  if [ "$ready" -eq 1 ]; then break; fi
done
if [ "$ready" -ne 1 ]; then echo 'RESTORED_SMOKE_READINESS_FAILED'; exit 1; fi

docker exec -e SQLCMDPASSWORD="$credential" "$container" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -b -Q "CREATE DATABASE [FrameworkContract] COLLATE SQL_Latin1_General_CP1_CS_AS; ALTER DATABASE [FrameworkContract] SET COMPATIBILITY_LEVEL=160; ALTER DATABASE [FrameworkContract] SET QUERY_STORE=ON; ALTER DATABASE [FrameworkContract] SET QUERY_STORE (OPERATION_MODE=READ_WRITE);" >/dev/null

docker exec -e SQLCMDPASSWORD="$credential" "$container" bash -lc '
  cd /workspace/Code/Install
  exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d FrameworkContract -b -i Install_All.sql
' >"$work_root/install.log" 2>&1 || {
  echo 'INSTALL_FAILURE_BEGIN'
  tail -n 40 "$work_root/install.log"
  echo 'INSTALL_FAILURE_END'
  exit 1
}

set +e
docker exec -e SQLCMDPASSWORD="$credential" "$container" bash -lc '
  cd /workspace/Code/Tests
  exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -d FrameworkContract -b -i Run_Release_Gate.sql
' >"$work_root/release.log" 2>&1
status=$?
set -e
if [ "$status" -ne 0 ]; then
  echo 'RELEASE_FAILURE_BEGIN'
  tail -n 40 "$work_root/release.log"
  echo 'RELEASE_FAILURE_END'
  exit "$status"
fi

if ! grep -q 'FRAMEWORK_USAGE_RUNTIME_CONTRACT PASS' "$work_root/release.log"; then
  echo 'FRAMEWORK_USAGE_PASS_MARKER_MISSING'
  tail -n 40 "$work_root/release.log"
  exit 1
fi

echo 'RESTORED_SMOKE_SQL2022_RELEASE_GATE PASS'
