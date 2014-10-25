Task default -depends Build

Properties {
    $source = $psake.build_script_dir
    $buildTarget = '~\Documents\WindowsPowerShell\Modules\GenericMethods'

    $filesToExclude = @(
        'README.md'
        'GenericMethods.Tests.ps1'
        'build.psake.ps1'
    )
}

Task Test {
    $result = Invoke-Pester -Path $source -PassThru
    $failed = $result.FailedCount

    if ($failed -gt 0)
    {
        throw "$failed unit tests failed; build aborting."
    }
}

Task Build -depends Test {
    if (Test-Path -Path $buildTarget -PathType Container)
    {
        Remove-Item -Path $buildTarget -Recurse -Force -ErrorAction Stop
    }

    $null = New-Item -Path $buildTarget -ItemType Directory -ErrorAction Stop

    Copy-Item -Path $source\* -Exclude $filesToExclude -Destination $buildTarget -Recurse -ErrorAction Stop
}

Task Sign {
    $CertThumbprint = 'A2E6B086AC438B5480365B2D5E48BB25F9BE69B3'
    $TimestampURL   = 'http://timestamp.digicert.com'

    $cert = $(Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertThumbprint -and $_.PrivateKey -is [System.Security.Cryptography.RSACryptoServiceProvider] } )

    if ($cert -eq $null) {
        throw 'My code signing certificate was not found!'
    }

    $properties = @(
        @{ Label = 'Name'; Expression = { Split-Path -Path $_.Path -Leaf } }
        'Status'
        @{ Label = 'SignerCertificate'; Expression = { $_.SignerCertificate.Thumbprint } }
        @{ Label = 'TimeStamperCertificate'; Expression = { $_.TimeStamperCertificate.Thumbprint } }
    )

    Get-ChildItem -Path $buildTarget\* -Include *.ps1, *.psm1, *.psd1, *.dll |
    Set-AuthenticodeSignature -Certificate $cert -TimestampServer $TimestampURL -Force -IncludeChain All -ErrorAction Stop |
    Format-Table -Property $properties -AutoSize
}
