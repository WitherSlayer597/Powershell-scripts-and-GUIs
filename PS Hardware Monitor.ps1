Add-Type -AssemblyName PresentationFramework, System.Drawing, System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# GUI
[xml]$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="System Monitor" Height="400" Width="360" Background="#121212" Topmost="True" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <StackPanel Margin="25">
        <TextBlock Text="Live Hardware Status" FontSize="16" Foreground="#61AFEF" HorizontalAlignment="Center" Margin="0,0,0,25" FontWeight="Bold"/>
        
        <DockPanel><TextBlock Text="CPU" Foreground="#ABB2BF" FontSize="12"/><TextBlock Name="cpuTxt" Text="0%" Foreground="White" HorizontalAlignment="Right" DockPanel.Dock="Right"/></DockPanel>
        <ProgressBar Name="cpuBar" Height="8" Maximum="100" Foreground="#61AFEF" Margin="0,5,0,18" Background="#252525" BorderThickness="0"/>
        
        <DockPanel><TextBlock Text="Memory" Foreground="#ABB2BF" FontSize="12"/><TextBlock Name="memTxt" Text="0%" Foreground="White" HorizontalAlignment="Right" DockPanel.Dock="Right"/></DockPanel>
        <ProgressBar Name="memBar" Height="8" Maximum="100" Foreground="#98C379" Margin="0,5,0,18" Background="#252525" BorderThickness="0"/>

        <DockPanel><TextBlock Text="Network (Mbps)" Foreground="#ABB2BF" FontSize="12"/><TextBlock Name="netTxt" Text="0.00" Foreground="White" HorizontalAlignment="Right" DockPanel.Dock="Right"/></DockPanel>
        <ProgressBar Name="netBar" Height="8" Maximum="100" Foreground="#C678DD" Margin="0,5,0,25" Background="#252525" BorderThickness="0"/>

        <Separator Background="#333" Margin="0,5"/>
        
        <DockPanel Margin="0,15,0,0">
            <TextBlock Text="GPU Utilization" Foreground="#E5C07B" FontSize="14" FontWeight="Bold"/>
            <TextBlock Name="gpuLoadTxt" Text="0%" Foreground="White" FontSize="14" HorizontalAlignment="Right" DockPanel.Dock="Right"/>
        </DockPanel>
        <ProgressBar Name="gpuBar" Height="12" Maximum="100" Foreground="#56B6C2" Margin="0,8,0,10" Background="#252525" BorderThickness="0"/>
        
        <TextBlock Name="gpuName" Text="Scanning..." Foreground="#5C6370" FontSize="10" HorizontalAlignment="Center" Margin="0,5,0,0"/>
    </StackPanel>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Map UI
$cpuBar = $window.FindName("cpuBar"); $cpuTxt = $window.FindName("cpuTxt")
$memBar = $window.FindName("memBar"); $memTxt = $window.FindName("memTxt")
$netBar = $window.FindName("netBar"); $netTxt = $window.FindName("netTxt")
$gpuBar = $window.FindName("gpuBar"); $gpuLoadTxt = $window.FindName("gpuLoadTxt")
$gpuName = $window.FindName("gpuName")


$cpuCounter = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")
try {
    $netCategory = New-Object System.Diagnostics.PerformanceCounterCategory("Network Interface")
    $instance = ($netCategory.GetInstanceNames() | Where-Object { $_ -notmatch 'Loopback|isatap|Teredo' })[0]
    $netCounter = New-Object System.Diagnostics.PerformanceCounter("Network Interface", "Bytes Received/sec", $instance)
} catch { $netCounter = $null }


$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)

$timer.Add_Tick({
    #CPU mon
    $vCpu = [math]::Round($cpuCounter.NextValue(), 0); $cpuBar.Value = $vCpu; $cpuTxt.Text = "$vCpu%"

    #MEM mon
    $os = Get-CimInstance Win32_OperatingSystem
    $vMem = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 0)
    $memBar.Value = $vMem; $memTxt.Text = "$vMem%"

    #Network mon
    if ($netCounter) {
        $nMbps = [math]::Round(($netCounter.NextValue() * 8) / 1MB, 2)
        $netBar.Value = [math]::Min(($nMbps * 2), 100) 
        $netTxt.Text = "$nMbps"
    }

    # GPU mon
    try {
        # This counter looks at all GPU engines. We take the max value seen across them.
        $gpuSamples = (Get-Counter "\GPU Engine(*)\Utilization Percentage" -ErrorAction SilentlyContinue).CounterSamples
        $maxGpu = ($gpuSamples.CookedValue | Measure-Object -Maximum).Maximum
        
        if ($maxGpu -ne $null) {
            $vGpu = [math]::Round($maxGpu, 0)
            $gpuBar.Value = [math]::Min($vGpu, 100)
            $gpuLoadTxt.Text = "$vGpu%"
        }
        
        # Static Name Update (only if empty)
        if ($gpuName.Text -eq "Scanning...") {
            $gpuName.Text = (Get-CimInstance Win32_VideoController).Name
        }
    } catch { }
})

$timer.Start()
$window.ShowDialog() | Out-Null