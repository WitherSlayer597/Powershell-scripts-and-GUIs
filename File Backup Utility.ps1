Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# --- XAML ---

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="File Backup Utility" Height="550" Width="500" Background="#F0F0F0">
    <StackPanel Margin="20">
        <TextBlock Text="Source Game File/Folder:" FontWeight="Bold" Margin="0,0,0,5"/>
        <DockPanel Margin="0,0,0,15">
            <Button Name="btnBrowseSource" Content="Browse" Width="60" DockPanel.Dock="Right"/>
            <TextBox Name="txtSourcePath" Height="25" VerticalContentAlignment="Center"/>
        </DockPanel>

        <TextBlock Text="Backup Destination:" FontWeight="Bold" Margin="0,0,0,5"/>
        <DockPanel Margin="0,0,0,15">
            <Button Name="btnBrowseDest" Content="Browse" Width="60" DockPanel.Dock="Right"/>
            <TextBox Name="txtDestPath" Height="25" VerticalContentAlignment="Center"/>
        </DockPanel>

        <TextBlock Text="Backup Interval (Minutes):" FontWeight="Bold" Margin="0,0,0,5"/>
        <ComboBox Name="cmbInterval" Height="25" Margin="0,0,0,15">
            <ComboBoxItem Content="5" IsSelected="True"/>
            <ComboBoxItem Content="10"/>
            <ComboBoxItem Content="15"/>
            <ComboBoxItem Content="30"/>
            <ComboBoxItem Content="45"/>
            <ComboBoxItem Content="60"/>
            <ComboBoxItem Content="120"/>
            <ComboBoxItem Content="180"/>
            <ComboBoxItem Content="240"/>
            <ComboBoxItem Content="300"/>
            <ComboBoxItem Content="360"/>
            <ComboBoxItem Content="1440"/>
        </ComboBox>

        <Button Name="btnRun" Content="Start Backup Timer" Height="40" Background="#4CAF50" Foreground="White" FontWeight="Bold" Margin="0,0,0,15"/>

        <TextBlock Text="Backup History / Destination Contents:" FontWeight="Bold" Margin="0,0,0,5"/>
        <ListBox Name="lstOutput" Height="150" Background="#FFFFFF" ScrollViewer.VerticalScrollBarVisibility="Auto"/>
        
        <StatusBar Margin="0,10,0,0">
            <StatusBarItem>
                <TextBlock Name="lblStatus" Text="Ready" Foreground="Gray"/>
            </StatusBarItem>
        </StatusBar>
    </StackPanel>
</Window>
"@


$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
}
catch {
    Write-Error "Failed to load XAML: $($_.Exception.Message)"
    return
}

#variables

$txtSource   = $window.FindName("txtSourcePath")
$txtDest     = $window.FindName("txtDestPath")
$cmbInterval = $window.FindName("cmbInterval")
$btnRun      = $window.FindName("btnRun")
$lstOutput   = $window.FindName("lstOutput")
$lblStatus   = $window.FindName("lblStatus")

# timer setup
$script:backupTimer = New-Object System.Windows.Threading.DispatcherTimer

function Refresh-BackupList {
    if (Test-Path $txtDest.Text) {
        $lstOutput.Items.Clear()
        Get-ChildItem $txtDest.Text | Sort-Object LastWriteTime -Descending | ForEach-Object {
            [void]$lstOutput.Items.Add("$($_.LastWriteTime.ToString('HH:mm:ss')) - $($_.Name)")
        }
    }
}

function Perform-Backup {
    $source = $txtSource.Text
    $destination = $txtDest.Text

    if (Test-Path $source) {
        try {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            # Get just the folder/file name to keep the backup organized
            $name = Split-Path $source -Leaf
            $destPath = Join-Path $destination "$name`_Backup_$timestamp"
            
            Copy-Item -Path $source -Destination $destPath -Recurse -Force
            $lblStatus.Text = "Last backup: $(Get-Date -Format 'HH:mm:ss')"
            Refresh-BackupList
        }
        catch {
            $lblStatus.Text = "Error: $($_.Exception.Message)"
        }
    }
    else {
        $script:backupTimer.Stop()
        $btnRun.Content = "Start Backup Timer"
        [System.Windows.MessageBox]::Show("Source path no longer exists! Timer stopped.")
    }
}

$btnRun.Add_Click({
    if ($script:backupTimer.IsEnabled) {
        $script:backupTimer.Stop()
        $btnRun.Content = "Start Backup Timer"
        $btnRun.Background = "#4CAF50"
        $lblStatus.Text = "Stopped"
    }
    else {
        #File path verification /validation
        if (-not (Test-Path $txtSource.Text)) {
            [System.Windows.MessageBox]::Show("Please select a valid Source file/folder.")
            return
        }
        if (-not (Test-Path $txtDest.Text)) {
            [System.Windows.MessageBox]::Show("Please select a valid Destination folder.")
            return
        }

        #Initialize Timer
        $minutes = [int]$cmbInterval.Text
        $script:backupTimer.Interval = [TimeSpan]::FromMinutes($minutes)
        $script:backupTimer.Start()
        
        $btnRun.Content = "STOP Backup Timer"
        $btnRun.Background = "#f44336" # Red for stop
        $lblStatus.Text = "Running (Every $minutes mins)"
        
        #Run first backup
        Perform-Backup
    }
})

$script:backupTimer.Add_Tick({
    Perform-Backup
})

#Browse source if you would like to (i just use copy as path)
$window.FindName("btnBrowseSource").Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select the Game Folder or File location"
    if ($dlg.ShowDialog() -eq "OK") { $txtSource.Text = $dlg.SelectedPath }
})

$window.FindName("btnBrowseDest").Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select where to save the backups"
    if ($dlg.ShowDialog() -eq "OK") { 
        $txtDest.Text = $dlg.SelectedPath 
        Refresh-BackupList
    }
})
#Run
$window.ShowDialog() | Out-Null