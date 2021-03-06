<#
    .SYNOPSIS
        Automated unit test for MSFT_SqlDatabaseRole DSC resource.

    .NOTES
        To run this script locally, please make sure to first run the bootstrap
        script. Read more at
        https://github.com/PowerShell/SqlServerDsc/blob/dev/CONTRIBUTING.md#bootstrap-script-assert-testenvironment
#>

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')

if (Test-SkipContinuousIntegrationTask -Type 'Unit')
{
    return
}

$script:dscModuleName = 'SqlServerDsc'
$script:dscResourceName = 'MSFT_SqlDatabaseRole'

#region HEADER

# Unit Test Template Version: 1.2.0
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ((-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
    (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))))
{
    & git.exe @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force

$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -TestType Unit

#endregion HEADER

function Invoke-TestSetup
{
    # Loading mocked classes
    Add-Type -Path (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Stubs') -ChildPath 'SMO.cs')
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
}

# Begin Testing
try
{
    Invoke-TestSetup

    InModuleScope $script:dscResourceName {
        $mockServerName = 'localhost'
        $mockInstanceName = 'MSSQLSERVER'
        $mockSqlDatabaseName = 'AdventureWorks'

        $mockSqlServerLogin1 = 'John'
        $mockSqlServerLogin1Type = 'WindowsUser'
        $mockSqlServerLogin2 = 'CONTOSO\KingJulian'
        $mockSqlServerLogin2Type = 'WindowsGroup'
        $mockSqlServerLogin3 = 'CONTOSO\SQLAdmin'
        $mockSqlServerLogin3Type = 'WindowsGroup'
        $mockSqlServerInvalidLogin = 'KingJulian'

        $mockSqlDatabaseRole1 = 'MyRole'
        $mockSqlDatabaseRole2 = 'MySecondRole'
        $mockSqlDatabaseRole3 = 'NewRole'

        $mockEnumMembers = @($mockSqlServerLogin1, $mockSqlServerLogin2)

        $mockExpectedSqlDatabaseRole = 'MyRole'

        $mockInvalidOperationForAddMemberMethod = $false
        $mockInvalidOperationForCreateMethod = $false
        $mockInvalidOperationForDropMethod = $false
        $mockInvalidOperationForDropMemberMethod = $false

        $mockExpectedMemberToAdd = 'MySecondRole'
        $mockExpectedMemberToDrop = 'MyRole'

        # Default parameters that are used for the It-blocks
        $mockDefaultParameters = @{
            ServerName   = $mockServerName
            InstanceName = $mockInstanceName
        }

        #region Function mocks
        $mockConnectSQL = {
            return @(
                (
                    New-Object -TypeName Object |
                    Add-Member -MemberType NoteProperty -Name InstanceName -Value $mockInstanceName -PassThru |
                    Add-Member -MemberType NoteProperty -Name ComputerNamePhysicalNetBIOS -Value $mockServerName -PassThru |
                    Add-Member -MemberType NoteProperty -Name NetName -Value $mockServerName -PassThru |
                    Add-Member -MemberType ScriptProperty -Name Databases -Value {
                        return @{
                            $mockSqlDatabase = @((
                                    New-Object -TypeName Object |
                                    Add-Member -MemberType NoteProperty -Name Name -Value $mockSqlDatabaseName -PassThru |
                                    Add-Member -MemberType ScriptProperty -Name Users -Value {
                                        return @{
                                            $mockSqlServerLogin1 = @((
                                                    New-Object -TypeName Object |
                                                    Add-Member -MemberType ScriptMethod -Name IsMember -Value {
                                                        param
                                                        (
                                                            [Parameter()]
                                                            [System.String]
                                                            $Name
                                                        )
                                                        if ($Name -eq $mockExpectedSqlDatabaseRole)
                                                        {
                                                            return $true
                                                        }
                                                        else
                                                        {
                                                            return $false
                                                        }
                                                    } -PassThru
                                                ))
                                            $mockSqlServerLogin2 = @((
                                                    New-Object -TypeName Object |
                                                    Add-Member -MemberType ScriptMethod -Name IsMember -Value {
                                                        return $true
                                                    } -PassThru
                                                ))
                                            $mockSqlServerLogin3 = @((
                                                    New-Object -TypeName Object |
                                                    Add-Member -MemberType ScriptMethod -Name IsMember -Value {
                                                        return $true
                                                    } -PassThru
                                                ))

                                        }
                                    } -PassThru |
                                    Add-Member -MemberType ScriptProperty -Name Roles -Value {
                                        return @{
                                            $mockSqlDatabaseRole1 = @((
                                                    New-Object -TypeName Object |
                                                    Add-Member -MemberType NoteProperty -Name Name -Value $mockSqlDatabaseRole1 -PassThru |
                                                    Add-Member -MemberType ScriptMethod -Name AddMember -Value {
                                                        param
                                                        (
                                                            [Parameter()]
                                                            [System.String]
                                                            $Name
                                                        )
                                                        if ($mockInvalidOperationForAddMemberMethod)
                                                        {
                                                            throw 'Mock AddMember Method was called with invalid operation.'
                                                        }
                                                        if ($Name -ne $mockExpectedMemberToAdd)
                                                        {
                                                            throw "Called mocked AddMember() method without adding the right user. Expected '{0}'. But was '{1}'." `
                                                                -f $mockExpectedMemberToAdd, $Name
                                                        }
                                                    } -PassThru |
                                                    Add-Member -MemberType ScriptMethod -Name Drop -Value {
                                                        if ($mockInvalidOperationForDropMethod)
                                                        {
                                                            throw 'Mock Drop Method was called with invalid operation.'
                                                        }

                                                        if ($Name -ne $mockExpectedSqlDatabaseRole)
                                                        {
                                                            throw "Called mocked Drop() method without dropping the right database role. Expected '{0}'. But was '{1}'." `
                                                                -f $mockExpectedSqlDatabaseRole, $Name
                                                        }
                                                    } -PassThru |
                                                    Add-Member -MemberType ScriptMethod -Name DropMember -Value {
                                                        param
                                                        (
                                                            [Parameter()]
                                                            [System.String]
                                                            $Name
                                                        )
                                                        if ($mockInvalidOperationForDropMemberMethod)
                                                        {
                                                            throw 'Mock DropMember Method was called with invalid operation.'
                                                        }
                                                        if ($Name -ne $mockExpectedMemberToDrop)
                                                        {
                                                            throw "Called mocked Drop() method without adding the right user. Expected '{0}'. But was '{1}'." `
                                                                -f $mockExpectedMemberToDrop, $Name
                                                        }
                                                    } -PassThru |
                                                    Add-Member -MemberType ScriptMethod -Name EnumMembers -Value {
                                                        if ($mockInvalidOperationForEnumMethod)
                                                        {
                                                            throw 'Mock EnumMembers Method was called with invalid operation.'
                                                        }
                                                        else
                                                        {
                                                            $mockEnumMembers
                                                        }
                                                    } -PassThru
                                                ))
                                            $mockSqlDatabaseRole2 = @((
                                                    New-Object -TypeName Object |
                                                    Add-Member -MemberType NoteProperty -Name Name -Value $mockSqlDatabaseRole2 -PassThru |
                                                    Add-Member -MemberType ScriptMethod -Name AddMember -Value {
                                                        param
                                                        (
                                                            [Parameter()]
                                                            [System.String]
                                                            $Name
                                                        )
                                                        if ($mockInvalidOperationForAddMemberMethod)
                                                        {
                                                            throw 'Mock AddMember Method was called with invalid operation.'
                                                        }
                                                        if ($Name -ne $mockExpectedMemberToAdd)
                                                        {
                                                            throw "Called mocked AddMember() method without adding the right user. Expected '{0}'. But was '{1}'." `
                                                                -f $mockExpectedMemberToAdd, $Name
                                                        }
                                                    } -PassThru |
                                                    Add-Member -MemberType ScriptMethod -Name DropMember -Value {
                                                        param
                                                        (
                                                            [Parameter()]
                                                            [System.String]
                                                            $Name
                                                        )
                                                        if ($mockInvalidOperationForDropMemberMethod)
                                                        {
                                                            throw 'Mock DropMember Method was called with invalid operation.'
                                                        }
                                                        if ($Name -ne $mockExpectedMemberToDrop)
                                                        {
                                                            throw "Called mocked Drop() method without adding the right user. Expected '{0}'. But was '{1}'." `
                                                                -f $mockExpectedMemberToDrop, $Name
                                                        }
                                                    } -PassThru
                                                ))
                                        }
                                    }-PassThru -Force
                                ))
                        }
                    } -PassThru -Force |
                    Add-Member -MemberType ScriptProperty -Name Logins -Value {
                        return @{
                            $mockSqlServerLogin1 = @((
                                    New-Object -TypeName Object |
                                    Add-Member -MemberType NoteProperty -Name LoginType -Value $mockSqlServerLogin1Type -PassThru
                                ))
                            $mockSqlServerLogin2 = @((
                                    New-Object -TypeName Object |
                                    Add-Member -MemberType NoteProperty -Name LoginType -Value $mockSqlServerLogin2Type -PassThru
                                ))
                            $mockSqlServerLogin3 = @((
                                    New-Object -TypeName Object |
                                    Add-Member -MemberType NoteProperty -Name LoginType -Value $mockSqlServerLogin3Type -PassThru
                                ))
                        }
                    } -PassThru -Force

                )
            )
        }

        $mockNewObjectDatabaseRole = {
            return @(
                New-Object -TypeName Object |
                Add-Member -MemberType NoteProperty -Name Name -Value $mockExpectedSqlDatabaseRole -PassThru |
                Add-Member -MemberType ScriptMethod -Name Create -Value {
                    if ($mockInvalidOperationForCreateMethod)
                    {
                        throw 'Mock Create Method was called with invalid operation.'
                    }
                    if ($this.Name -ne $mockExpectedSqlDatabaseRole)
                    {
                        throw "Called mocked Create() method without adding the right user. Expected '{0}'. But was '{1}'." `
                            -f $mockExpectedSqlDatabaseRole, $this.Name
                    }
                } -PassThru -Force
            )
        }
        #endregion

        Describe 'MSFT_SqlDatabaseRole\Get-TargetResource' -Tag 'Get' {
            BeforeEach {
                Mock -CommandName Connect-SQL -MockWith $mockConnectSQL -Verifiable
            }

            Context 'When only key parameters have values and database name does not exist' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database = 'unknownDatabaseName'
                    Name     = $mockSqlDatabaseRole1
                }

                It 'Should throw the correct error' {
                    $errorMessage = $script:localizedData.DatabaseNotFound -f $testParameters.Database

                    { Get-TargetResource @testParameters } | Should -Throw $errorMessage
                }

                It 'Should call the mock function Connect-SQL' {
                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope Context
                }
            }

            Context 'When only key parameters have values and the role does not exist' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database = $mockSqlDatabaseName
                    Name     = 'UnknownRoleName'
                }

                It 'Should return the state as Absent' {
                    $result = Get-TargetResource @testParameters
                    $result.Ensure | Should -Be 'Absent'

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the members as null' {
                    $result = Get-TargetResource @testParameters
                    $result.Members | Should -BeNullOrEmpty

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the same values as passed as parameters' {
                    $result = Get-TargetResource @testParameters
                    $result.ServerName | Should -Be $testParameters.ServerName
                    $result.InstanceName | Should -Be $testParameters.InstanceName
                    $result.Database | Should -Be $testParameters.Database
                    $result.Name | Should -Be $testParameters.Name

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When only key parameters have values and the role exists' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database = $mockSqlDatabaseName
                    Name     = $mockSqlDatabaseRole1
                }

                It 'Should return the state as Present' {
                    $result = Get-TargetResource @testParameters
                    $result.Ensure | Should -Be 'Present'

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should call the mock function Connect-SQL' {
                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope Context
                }
            }

            Context 'When only key parameters have values and throwing with EnumMembers method' {
                $mockInvalidOperationForEnumMethod = $true
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database = $mockSqlDatabaseName
                    Name     = $mockSqlDatabaseRole1
                }

                It 'Should throw the correct error' {
                    $errorMessage = $script:localizedData.EnumDatabaseRoleMemberNamesError -f $mockSqlDatabaseRole1, $mockSqlDatabaseName

                    { Get-TargetResource @testParameters } | Should -Throw $errorMessage
                }

                It 'Should call the mock function Connect-SQL' {
                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope Context
                }
            }

            Context 'When parameter Members is assigned a value, the role exists, and the role members are in the desired state' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database = $mockSqlDatabaseName
                    Name     = $mockSqlDatabaseRole1
                    Members  = $mockEnumMembers
                }

                It 'Should return Ensure as Present' {
                    $result = Get-TargetResource @testParameters
                    $result.Ensure | Should -Be 'Present'

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return MembersInDesiredState as True' {
                    $result = Get-TargetResource @testParameters
                    $result.MembersInDesiredState | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the members as not null' {
                    $result = Get-TargetResource @testParameters
                    $result.Members | Should -Be $testParameters.Members

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the members as string array' {
                    $result = Get-TargetResource @testParameters
                    ($result.Members -is [System.String[]]) | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the same values as passed as parameters' {
                    $result = Get-TargetResource @testParameters
                    $result.ServerName | Should -Be $testParameters.ServerName
                    $result.InstanceName | Should -Be $testParameters.InstanceName
                    $result.Database | Should -Be $testParameters.Database
                    $result.Name | Should -Be $testParameters.Name
                    $result.Members | Should -Be $testParameters.Members

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When parameter Members is assigned a value, the role exists, and the role members are not in the desired state' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database = $mockSqlDatabaseName
                    Name     = $mockSqlDatabaseRole1
                    Members  = @($mockSqlServerLogin1, $mockSqlServerLogin3)
                }

                It 'Should return Ensure as Present' {
                    $result = Get-TargetResource @testParameters
                    $result.Ensure | Should -Be 'Present'

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return MembersInDesiredState as False' {
                    $result = Get-TargetResource @testParameters
                    $result.MembersInDesiredState | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the members as string array' {
                    $result = Get-TargetResource @testParameters
                    ($result.Members -is [System.String[]]) | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When both parameters MembersToInclude and Members are assigned a value' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database         = $mockSqlDatabaseName
                    Name             = $mockSqlDatabaseRole1
                    Members          = $mockEnumMembers
                    MembersToInclude = $mockSqlServerLogin1
                }

                It 'Should throw the correct error' {
                    $errorMessage = $script:localizedData.MembersToIncludeAndExcludeParamMustBeNull

                    { Get-TargetResource @testParameters } | Should -Throw $errorMessage
                }

                It 'Should call the mock function Connect-SQL' {
                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope Context
                }
            }

            Context 'When parameter MembersToInclude is assigned a value, the role exists, and the role members are in the desired state' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database         = $mockSqlDatabaseName
                    Name             = $mockSqlDatabaseRole1
                    MembersToInclude = $mockSqlServerLogin1
                }

                It 'Should return Ensure as Present' {
                    $result = Get-TargetResource @testParameters
                    $result.Ensure | Should -Be 'Present'

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return MembersInDesiredState as True' {
                    $result = Get-TargetResource @testParameters
                    $result.MembersInDesiredState | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the members as not null' {
                    $result = Get-TargetResource @testParameters
                    $result.Members | Should -Not -BeNullOrEmpty

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the members as string array' {
                    $result = Get-TargetResource @testParameters
                    ($result.Members -is [System.String[]]) | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the same values as passed as parameters' {
                    $result = Get-TargetResource @testParameters
                    $result.ServerName | Should -Be $testParameters.ServerName
                    $result.InstanceName | Should -Be $testParameters.InstanceName
                    $result.Database | Should -Be $testParameters.Database
                    $result.Name | Should -Be $testParameters.Name
                    $result.MembersToInclude | Should -Be $testParameters.MembersToInclude

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When parameter MembersToInclude is assigned a value, the role exists, and the role members are not in the desired state' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database         = $mockSqlDatabaseName
                    Name             = $mockSqlDatabaseRole1
                    MembersToInclude = $mockSqlServerLogin3
                }

                It 'Should return Ensure as Present' {
                    $result = Get-TargetResource @testParameters
                    $result.Ensure | Should -Be 'Present'

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return MembersInDesiredState as False' {
                    $result = Get-TargetResource @testParameters
                    $result.MembersInDesiredState | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the members as string array' {
                    $result = Get-TargetResource @testParameters
                    ($result.Members -is [System.String[]]) | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When both parameters MembersToExclude and Members are assigned a value' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database         = $mockSqlDatabaseName
                    Name             = $mockSqlDatabaseRole1
                    Members          = $mockEnumMembers
                    MembersToExclude = $mockSqlServerLogin1
                }

                It 'Should throw the correct error' {
                    $errorMessage = $script:localizedData.MembersToIncludeAndExcludeParamMustBeNull

                    { Get-TargetResource @testParameters } | Should -Throw $errorMessage
                }

                It 'Should call the mock function Connect-SQL' {
                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope Context
                }

            }

            Context 'When parameter MembersToExclude is assigned a value, the role exists, and the role members are in the desired state' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database         = $mockSqlDatabaseName
                    Name             = $mockSqlDatabaseRole1
                    MembersToExclude = $mockSqlServerLogin3
                }

                It 'Should return Ensure as Present' {
                    $result = Get-TargetResource @testParameters
                    $result.Ensure | Should -Be 'Present'

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return MembersInDesiredState as True' {
                    $result = Get-TargetResource @testParameters
                    $result.MembersInDesiredState | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the same values as passed as parameters' {
                    $result = Get-TargetResource @testParameters
                    $result.ServerName | Should -Be $testParameters.ServerName
                    $result.InstanceName | Should -Be $testParameters.InstanceName
                    $result.Database | Should -Be $testParameters.Database
                    $result.Name | Should -Be $testParameters.Name
                    $result.MembersToExclude | Should -Be $testParameters.MembersToExclude

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When parameter MembersToExclude is assigned a value, the role exists, and the role members are not in the desired state' {
                $testParameters = $mockDefaultParameters
                $testParameters += @{
                    Database         = $mockSqlDatabaseName
                    Name             = $mockSqlDatabaseRole1
                    MembersToExclude = $mockSqlServerLogin2
                }

                It 'Should return Ensure as Present' {
                    $result = Get-TargetResource @testParameters
                    $result.Ensure | Should -Be 'Present'

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return MembersInDesiredState as False' {
                    $result = Get-TargetResource @testParameters
                    $result.MembersInDesiredState | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return the members as string array' {
                    $result = Get-TargetResource @testParameters
                    ($result.Members -is [System.String[]]) | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Assert-VerifiableMock
        }

        Describe "MSFT_SqlServerRole\Set-TargetResource" -Tag 'Set' {
            BeforeEach {
                Mock -CommandName Connect-SQL -MockWith $mockConnectSQL -Verifiable
                Mock -CommandName New-Object -MockWith $mockNewObjectDatabaseRole -ParameterFilter {
                    $TypeName -eq 'Microsoft.SqlServer.Management.Smo.DatabaseRole'
                }
            }

            Context 'When the system is not in the desired state and Ensure is set to Absent' {
                It 'Should not throw when calling the Drop method' {
                    $mockSqlDatabaseRoleToDrop = 'DatabaseRoleToDrop'
                    $mockExpectedSqlDatabaseRole = 'DatabaseRoleToDrop'
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRoleToDrop
                        Ensure   = 'Absent'
                    }

                    { Set-TargetResource @testParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When the system is not in the desired state and Ensure is set to Absent' {
                It 'Should throw the correct error when calling the Drop method' {
                    $mockInvalidOperationForDropMethod = $true
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRole1
                        Ensure   = 'Absent'
                    }

                    $errorMessage = $script:localizedData.DropDatabaseRoleError -f $mockSqlDatabaseRole1, $mockSqlDatabaseName

                    { Set-TargetResource @testParameters } | Should -Throw $errorMessage

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When the system is not in the desired state and Ensure is set to Present' {
                It 'Should not throw when calling the Create method' {
                    $mockSqlDatabaseRoleAdd = 'DatabaseRoleToAdd'
                    $mockExpectedSqlDatabaseRole = 'DatabaseRoleToAdd'
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRoleAdd
                        Ensure   = 'Present'
                    }

                    { Set-TargetResource @testParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should call the mock function New-Object with TypeName equal to Microsoft.SqlServer.Management.Smo.DatabaseRole' {
                    Assert-MockCalled -CommandName New-Object -Exactly -Times 1 -ParameterFilter {
                        $TypeName -eq 'Microsoft.SqlServer.Management.Smo.DatabaseRole'
                    } -Scope Context
                }
            }

            Context 'When the system is not in the desired state and Ensure is set to Present' {
                It 'Should throw the correct error when calling the Create method' {
                    $mockSqlDatabaseRoleAdd = 'DatabaseRoleToAdd'
                    $mockExpectedSqlDatabaseRole = 'DatabaseRoleToAdd'
                    $mockInvalidOperationForCreateMethod = $true
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRoleAdd
                        Ensure   = 'Present'
                    }

                    $errorMessage = $script:localizedData.CreateDatabaseRoleError -f $mockSqlDatabaseRoleAdd, $mockSqlDatabaseName

                    { Set-TargetResource @testParameters } | Should -Throw $errorMessage

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should call the mock function New-Object with TypeName equal to Microsoft.SqlServer.Management.Smo.DatabaseRole' {
                    Assert-MockCalled -CommandName New-Object -Exactly -Times 1 -ParameterFilter {
                        $TypeName -eq 'Microsoft.SqlServer.Management.Smo.DatabaseRole'
                    } -Scope Context
                }
            }

            Context 'When parameter Members is assigned a value and Ensure is set to Present' {
                It 'Should throw the correct error when database user does not exist' {
                    $mockExpectedMemberToAdd = $mockSqlServerInvalidLogin
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRole1
                        Members  = @($mockSqlServerInvalidLogin, $mockSqlServerLogin1, $mockSqlServerLogin2)
                        Ensure   = 'Present'
                    }

                    $errorMessage = $script:localizedData.DatabaseUserNotFound -f $mockSqlServerInvalidLogin, $mockSqlDatabaseName

                    { Set-TargetResource @testParameters } | Should -Throw $errorMessage

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should not throw when calling both the AddMember and DropMember methods' {
                    $mockExpectedMemberToAdd = $mockSqlServerLogin3
                    $mockExpectedMemberToDrop = $mockSqlServerLogin2
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRole1
                        Members  = @($mockSqlServerLogin1, $mockSqlServerLogin3)
                        Ensure   = 'Present'
                    }

                    { Set-TargetResource @testParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When both parameters Members and MembersToInclude are assigned a value and Ensure is set to Present' {
                It 'Should throw the correct error' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        Members          = $mockEnumMembers
                        MembersToInclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    $errorMessage = $script:localizedData.MembersToIncludeAndExcludeParamMustBeNull

                    { Set-TargetResource @testParameters } | Should -Throw $errorMessage

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When parameter MembersToInclude is assigned a value, parameter Members is not assigned a value, and Ensure is set to Present' {
                It 'Should throw the correct error when the database user does not exist' {
                    $mockExpectedMemberToAdd = $mockSqlServerLogin3
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToInclude = $mockSqlServerInvalidLogin
                        Ensure           = 'Present'
                    }

                    $errorMessage = $script:localizedData.DatabaseUserNotFound -f $mockSqlServerInvalidLogin, $mockSqlDatabaseName

                    { Set-TargetResource @testParameters } | Should -Throw $errorMessage

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should not throw when calling the AddMember method' {
                    $mockExpectedMemberToAdd = $mockSqlServerLogin3
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToInclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    { Set-TargetResource @testParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should throw the correct error when calling the AddMember method' {
                    $mockInvalidOperationForAddMemberMethod = $true
                    $mockExpectedMemberToAdd = $mockSqlServerLogin3
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToInclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    $errorMessage = $script:localizedData.AddDatabaseRoleMemberError -f $mockSqlServerLogin3, $mockSqlDatabaseRole1, $mockSqlDatabaseName

                    { Set-TargetResource @testParameters } | Should -Throw $errorMessage

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When both parameters Members and MembersToExclude are assigned a value and Ensure is set to Present' {
                It 'Should throw the correct error' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        Members          = $mockEnumMembers
                        MembersToExclude = $mockSqlServerLogin2
                        Ensure           = 'Present'
                    }

                    $errorMessage = $script:localizedData.MembersToIncludeAndExcludeParamMustBeNull

                    { Set-TargetResource @testParameters } | Should -Throw $errorMessage

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When parameter MembersToExclude is assigned a value, parameter Members is not assigned a value, and Ensure is set to Present' {
                It 'Should not throw when calling the DropMember method' {
                    $mockExpectedMemberToDrop = $mockSqlServerLogin3
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToExclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    { Set-TargetResource @testParameters } | Should -Not -Throw

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should throw the correct error when calling the DropMember method' {
                    $mockInvalidOperationForDropMemberMethod = $true
                    $mockExpectedMemberToDrop = $mockSqlServerLogin2
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToExclude = $mockSqlServerLogin2
                        Ensure           = 'Present'
                    }

                    $errorMessage = $script:localizedData.DropDatabaseRoleMemberError -f $mockSqlServerLogin2, $mockSqlDatabaseRole1, $mockSqlDatabaseName

                    { Set-TargetResource @testParameters } | Should -Throw $errorMessage

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Assert-VerifiableMock
        }

        Describe "MSFT_SqlDatabaseRole\Test-TargetResource" -Tag 'Test' {
            BeforeEach {
                Mock -CommandName Connect-SQL -MockWith $mockConnectSQL -Verifiable
            }

            Context 'When the system is not in the desired state and Ensure is set to Absent' {
                It 'Should return False when the desired database role exists' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRole1
                        Ensure   = 'Absent'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When the system is not in the desired state and Ensure is set to Present' {
                It 'Should return True when the desired database role does not exist' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRole3
                        Ensure   = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When the system is in the desired state and Ensure is set to Absent' {
                It 'Should return True when the desired database role does not exist' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRole3
                        Ensure   = 'Absent'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When the system is in the desired state and Ensure is set to Present' {
                It 'Should return True when the desired database role exists' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRole1
                        Ensure   = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When parameter Members is assigned a value and Ensure parameter is set to Present' {
                It 'Should return False when the desired members are not in the desired database role' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database = $mockSqlDatabaseName
                        Name     = $mockSqlDatabaseRole1
                        Members  = @($mockSqlServerLogin3)
                        Ensure   = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When both parameters Members and MembersToInclude are assigned a value and Ensure is set to Present' {
                It 'Should throw the correct error' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        Members          = $mockEnumMembers
                        MembersToInclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    $errorMessage = $script:localizedData.MembersToIncludeAndExcludeParamMustBeNull

                    { Test-TargetResource @testParameters } | Should -Throw $errorMessage
                }

                It 'Should call the mock function Connect-SQL' {
                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope Context
                }
            }

            Context 'When parameter MembersToInclude is assigned a value, parameter Members is not assigned a value, and Ensure is set to Present' {
                It 'Should return False when desired database role does not exist' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole3
                        MembersToInclude = $mockSqlServerLogin1
                        Ensure           = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return True when the desired database role exists and the MembersToInclude contains members that already exist' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToInclude = $mockSqlServerLogin2
                        Ensure           = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return False when the desired database role exists and the MembersToInclude contains members that are missing' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToInclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Context 'When both parameters Members and MembersToExclude are assigned a value and Ensure is set to Present' {
                It 'Should throw the correct error' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        Members          = $mockEnumMembers
                        MembersToExclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    $errorMessage = $script:localizedData.MembersToIncludeAndExcludeParamMustBeNull

                    { Test-TargetResource @testParameters } | Should -Throw $errorMessage
                }

                It 'Should call the mock function Connect-SQL' {
                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope Context
                }
            }

            Context 'When parameter MembersToExclude is assigned a value, parameter Members is not assigned a value, and Ensure is set to Present' {
                It 'Should return False when desired database role does not exist' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole3
                        MembersToExclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return True when the desired database role exists and the MembersToExclude contains members that do not yet exist' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToExclude = $mockSqlServerLogin3
                        Ensure           = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $true

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }

                It 'Should return False when the desired database role exists and the MembersToExclude contains members that already exist' {
                    $testParameters = $mockDefaultParameters
                    $testParameters += @{
                        Database         = $mockSqlDatabaseName
                        Name             = $mockSqlDatabaseRole1
                        MembersToExclude = $mockSqlServerLogin1
                        Ensure           = 'Present'
                    }

                    $result = Test-TargetResource @testParameters
                    $result | Should -Be $false

                    Assert-MockCalled -CommandName Connect-SQL -Exactly -Times 1 -Scope It
                }
            }

            Assert-VerifiableMock
        }
        Describe 'SqlDatabaseRole\Export-TargetResource' {
            Mock -CommandName Connect-SQL -MockWith $mockConnectSQL

            # Mocking for protocol TCP
            Mock -CommandName Get-ItemProperty -ParameterFilter { $Path -eq $registryPath -and $Name -eq $name } -MockWith {
                return @{
                    'MyAlias' = 'DBMSSOCN,sqlnode.company.local,1433'
                }
            } -Verifiable

            Mock -CommandName Get-ItemProperty -ParameterFilter { $Path -eq $registryPathWow6432Node -and $Name -eq $name } -MockWith {
                return @{
                    'MyAlias' = 'DBMSSOCN,sqlnode.company.local,1433'
                }
            } -Verifiable

            Mock -CommandName Get-ItemProperty -ParameterFilter { $Path -eq $registryPath -and $Name -eq $nameDifferentTcpPort } -MockWith {
                return @{
                    'DifferentTcpPort' = 'DBMSSOCN,sqlnode.company.local,1500'
                }
            } -Verifiable

            Mock -CommandName Get-ItemProperty -ParameterFilter { $Path -eq $registryPathWow6432Node -and $Name -eq $nameDifferentTcpPort } -MockWith {
                return @{
                    'DifferentTcpPort' = 'DBMSSOCN,sqlnode.company.local,1500'
                }
            } -Verifiable

            Mock -CommandName Get-ItemProperty -ParameterFilter { $Path -eq $registryPath -and $Name -eq $nameDifferentServerNameTcp } -MockWith {
                return @{
                    'DifferentServerNameTcp' = 'DBMSSOCN,unknownserver.company.local,1433'
                }
            } -Verifiable

            Mock -CommandName Get-ItemProperty -ParameterFilter { $Path -eq $registryPathWow6432Node -and $Name -eq $nameDifferentServerNameTcp } -MockWith {
                return @{
                    'DifferentServerNameTcp' = 'DBMSSOCN,unknownserver.company.local,1433'
                }
            } -Verifiable

            Mock -CommandName Get-ItemProperty -ParameterFilter { $Path -eq $registryPath -and $Name -eq $unknownName } -MockWith {
                return $null
            } -Verifiable

            # Mocking 64-bit OS
            Mock -CommandName Get-CimInstance -MockWith {
                return New-Object -TypeName Object |
                    Add-Member -MemberType NoteProperty -Name OSArchitecture -Value '64-bit' -PassThru -Force
            } -ParameterFilter { $ClassName -eq 'win32_OperatingSystem' } -Verifiable

            Context 'Extract the existing configuration' {
                $result = Export-TargetResource


                It 'Should return content from the extraction' {
                    $result | Should -Not -Be $null
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
