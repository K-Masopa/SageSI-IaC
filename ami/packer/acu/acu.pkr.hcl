packer {
  required_version = ">= 1.7.5"
  required_plugins {
    amazon = {
      version = ">= 0.0.1"
      source  = "github.com/hashicorp/amazon"
    }

    windows-update = {
      version = "0.14.0"
      source  = "github.com/rgl/windows-update"
    }
  }
}

data "amazon-ami" "acu" {
  filters = {
    name                = "Windows_Server-2019-English-Full-Base-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]

  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# "timestamp" template function replacement
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "acu" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"

  ami_name                    = "SBCPP-ACU-${local.timestamp}"
  associate_public_ip_address = true
  instance_type               = "t3.medium"
  source_ami                  = "${data.amazon-ami.acu.id}"
  user_data_file              = "./ami/packer/acu/scripts/UserData.ps1"

  communicator   = "winrm"
  winrm_insecure = "true"
  winrm_timeout  = "15m"
  winrm_use_ssl  = "true"
  winrm_username = "Administrator"
}

build {
  sources = ["source.amazon-ebs.acu"]

  provisioner "windows-shell" {
    inline = ["cmd /c if exist c:\\DeployTemp rd /s /q c:\\DeployTemp", "cmd /c mkdir c:\\DeployTemp"]
  }

  provisioner "file" {
    destination = "C:\\DeployTemp\\"
    source      = "./ami/packer/acu/scripts/"
  }

  provisioner "powershell" {
    inline = ["cd C:\\DeployTemp", "ls", "C:\\DeployTemp\\Initialize-ImageBuilder.ps1"]
  }

  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted after DSC 1st run.'}\""
    restart_timeout       = "60m"
  }

  provisioner "powershell" {
    inline = ["cd C:\\DeployTemp", "ls", "C:\\DeployTemp\\Initialize-ImageBuilder.ps1"]
  }

  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted after DSC 2nd run.'}\""
    restart_timeout       = "60m"
  }

  // provisioner "windows-update" {
  // }

  // provisioner "windows-restart" {
  //   restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted after Windows Updates.'}\""
  //   restart_timeout       = "60m"
  // }

  provisioner "powershell" {
    inline = ["cd C:\\DeployTemp", "ls", "C:\\DeployTemp\\Initialize-NetOptimizationService"]
  }

  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted after NetOptimizationService.'}\""
    restart_timeout       = "60m"
  }

  provisioner "powershell" {
    inline = ["if( Test-Path $Env:SystemRoot\\windows\\system32\\Sysprep\\unattend.xml ){ rm $Env:SystemRoot\\windows\\system32\\Sysprep\\unattend.xml -Force}", "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit", "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; Write-Output $imageState.ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Start-Sleep -s 10 } else { break } }"]
  }
  post-processor "manifest" {
  }

}
