@{
    SchemaVersion = '1.0'
    DataClassification = 'SYNTHETIC_EXAMPLE'
    ExecutionMode = 'AUTO'
    AllowedExecutionModes = @(
        'WINDOWS_SINGLE_HOST'
        'LINUX_NATIVE'
        'DISTRIBUTED'
    )
    SqlVersionPriority = @(2025, 2022, 2019)
    ContainerEngine = 'DOCKER'
    ResourceProfile = 'Compact'

    StorageRoleBindings = @{
        IMAGE_CACHE = 'LOCAL_TARGET_REFERENCE_REQUIRED'
        ACTIVE_VM = 'LOCAL_TARGET_REFERENCE_REQUIRED'
        EPHEMERAL_DATA = 'LOCAL_TARGET_REFERENCE_REQUIRED'
        FAULT_TARGET = 'DEDICATED_BOUNDED_TARGET_REFERENCE_REQUIRED'
    }

    MediaBindings = @{
        WINDOWS_SERVER = 'LOCAL_MEDIA_REFERENCE_REQUIRED'
        SQL_SERVER = 'LOCAL_MEDIA_REFERENCE_REQUIRED'
    }

    NetworkPolicy = @{
        PrivateRangeReference = 'LOCAL_PRIVATE_RANGE_REFERENCE_REQUIRED'
        RejectRouteCollision = $true
        AllowExternalLabDataNetwork = $false
    }

    Retention = @{
        MaximumCacheAgeDays = 30
        MaximumArtifactAgeDays = 7
    }

    Timeouts = @{
        PreflightSeconds = 120
        SetupSeconds = 1800
        ObserveSeconds = 300
        CleanupSeconds = 900
    }
}

