# Invoked with static EncodedCommand; private request/response use anonymous pipes.
# Only the CurrentUser DPAPI ciphertext is stored. No password, raw token or key file.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
    # Godot sends UTF-8 JSON. Windows PowerShell otherwise decodes redirected stdin
    # using its console code page, corrupting the Korean game directory and payload.
    [Console]::InputEncoding = New-Object Text.UTF8Encoding($false)
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
    Add-Type -AssemblyName System.Security
    $request = [Console]::In.ReadLine() | ConvertFrom-Json
    $path = [IO.Path]::GetFullPath([string]$request.path)
    $entropy = [Text.Encoding]::UTF8.GetBytes('dothanjan.desktop.session.v1')
    $scope = [Security.Cryptography.DataProtectionScope]::CurrentUser
    switch ($request.action) {
        'load' {
            if ([IO.File]::Exists($path)) {
                $cipher = [IO.File]::ReadAllBytes($path)
                if ($cipher.Length -gt 32768) { throw 'Invalid credential envelope' }
                $plain = [Security.Cryptography.ProtectedData]::Unprotect($cipher, $entropy, $scope)
                $payload = [Text.Encoding]::UTF8.GetString($plain)
            } else { $payload = '' }
            [Console]::Out.WriteLine((@{ok=$true;payload=$payload} | ConvertTo-Json -Compress))
        }
        'save' {
            $plain = [Text.Encoding]::UTF8.GetBytes([string]$request.payload)
            if ($plain.Length -gt 8192) { throw 'Invalid credential size' }
            $cipher = [Security.Cryptography.ProtectedData]::Protect($plain, $entropy, $scope)
            $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
            $temporary = $path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
            $stream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $stream.Write($cipher, 0, $cipher.Length); $stream.Flush($true) } finally { $stream.Dispose() }
            if ([IO.File]::Exists($path)) {
                $backup = $path + '.bak'
                [IO.File]::Replace($temporary, $path, $backup)
                [IO.File]::Delete($backup)
            }
            else { [IO.File]::Move($temporary, $path) }
            [Console]::Out.WriteLine('{"ok":true}')
        }
        'clear' {
            [IO.File]::Delete($path)
            [IO.File]::Delete($path + '.bak')
            [Console]::Out.WriteLine('{"ok":true}')
        }
        default { throw 'Invalid storage action' }
    }
} catch {
    # Never echo a provider credential, payload, command or exception message.
    [Console]::Out.WriteLine('{"ok":false}')
    exit 1
}
