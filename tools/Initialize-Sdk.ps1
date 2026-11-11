# Only changes the repository-owned SDK copy. Never touches machine configuration.
param([Parameter(Mandatory)][string]$ToolsPath)
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $ToolsPath 'MakePQX.exe.config'
[xml]$config = Get-Content -LiteralPath $configPath
$ns = [Xml.XmlNamespaceManager]::new($config.NameTable)
$ns.AddNamespace('asm', 'urn:schemas-microsoft-com:asm.v1')
$existing = $config.SelectSingleNode('//asm:dependentAssembly[asm:assemblyIdentity/@name="System.Threading.Tasks.Extensions"]', $ns)
if (-not $existing) {
    # SdkTools 2.155.2 ships assembly 4.2.1.0, but MakePQX's JSON serializer
    # references 4.2.0.1. The package omits this .NET Framework binding redirect.
    $assembly = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $ToolsPath 'System.Threading.Tasks.Extensions.dll'))
    if ($assembly.Version.ToString() -ne '4.2.1.0') { throw 'Unexpected SDK assembly; review the compatibility adjustment.' }
    $binding = $config.CreateElement('assemblyBinding', 'urn:schemas-microsoft-com:asm.v1')
    $dependent = $config.CreateElement('dependentAssembly', 'urn:schemas-microsoft-com:asm.v1')
    $identity = $config.CreateElement('assemblyIdentity', 'urn:schemas-microsoft-com:asm.v1')
    $identity.SetAttribute('name', 'System.Threading.Tasks.Extensions')
    $identity.SetAttribute('publicKeyToken', 'cc7b13ffcd2ddd51')
    $identity.SetAttribute('culture', 'neutral')
    $redirect = $config.CreateElement('bindingRedirect', 'urn:schemas-microsoft-com:asm.v1')
    $redirect.SetAttribute('oldVersion', '0.0.0.0-4.2.1.0')
    $redirect.SetAttribute('newVersion', '4.2.1.0')
    [void]$dependent.AppendChild($identity)
    [void]$dependent.AppendChild($redirect)
    [void]$binding.AppendChild($dependent)
    [void]$config.configuration.runtime.AppendChild($binding)
    $config.Save($configPath)
}
