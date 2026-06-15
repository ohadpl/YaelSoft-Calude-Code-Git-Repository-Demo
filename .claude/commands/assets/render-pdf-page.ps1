param(
  [Parameter(Mandatory=$true)][string]$Pdf,
  [int]$Page = 0,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$Width = 1100
)
# Renders one page of a PDF to PNG using the built-in Windows.Data.Pdf WinRT API.
# Must be run with Windows PowerShell 5.1 (powershell.exe), not pwsh 7.
Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null

$wrt = [System.WindowsRuntimeSystemExtensions].GetMethods()
$asTaskOp = ($wrt | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskAct = ($wrt | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
function AwaitOp($op, $t) { $task = $asTaskOp.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
function AwaitAct($act) { $task = $asTaskAct.Invoke($null, @($act)); $task.Wait(-1) | Out-Null }

[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
[Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime] | Out-Null
[Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null

$file = AwaitOp ([Windows.Storage.StorageFile]::GetFileFromPathAsync($Pdf)) ([Windows.Storage.StorageFile])
$doc  = AwaitOp ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
if ($Page -ge $doc.PageCount) { throw "Page $Page out of range (PageCount=$($doc.PageCount))" }
$pg = $doc.GetPage([uint32]$Page)

$ms = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
$opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
$opts.DestinationWidth = [uint32]$Width
AwaitAct ($pg.RenderToStreamAsync($ms, $opts))

$ms.Seek(0)
$size = [uint32]$ms.Size
$reader = New-Object Windows.Storage.Streams.DataReader($ms.GetInputStreamAt(0))
AwaitOp ($reader.LoadAsync($size)) ([uint32]) | Out-Null
$bytes = New-Object byte[] $size
$reader.ReadBytes($bytes)
[IO.File]::WriteAllBytes($Out, $bytes)
Write-Output ("Rendered page {0} of {1} -> {2} ({3} bytes)" -f $Page, $doc.PageCount, $Out, $bytes.Length)
