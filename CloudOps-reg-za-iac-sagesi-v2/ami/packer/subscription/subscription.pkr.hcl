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

data "amazon-ami" "subscription" {
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

source "amazon-ebs" "subscription" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"

  ami_name                    = "SBCPP-SUBSCRIPTION-${local.timestamp}"
  associate_public_ip_address = true
  instance_type               = "t3.medium"
  source_ami                  = "${data.amazon-ami.subscription.id}"
  user_data_file              = "./ami/packer/subscription/scripts/UserData.ps1"

  ami_users = "${var.target_accounts}"

  temporary_iam_instance_profile_policy_document {
    Statement {
          Action   = ["s3:*"]
          Effect   = "Allow"
          Resource = ["arn:aws:s3:::${var.deployment_bucket}", "arn:aws:s3:::${var.deployment_bucket}/*"]
    }
    Statement {
          Action   = ["s3:ListAllMyBuckets"]
          Effect   = "Allow"
          Resource = ["*"]
    }     
    Version = "2012-10-17"
  }

  communicator   = "winrm"
  winrm_insecure = "true"
  winrm_timeout  = "15m"
  winrm_use_ssl  = "true"
  winrm_username = "Administrator"
}

build {
  sources = ["source.amazon-ebs.subscription"]

  provisioner "windows-shell" {
    inline = ["cmd /c if exist c:\\amiscripts rd /s /q c:\\amiscripts", "cmd /c mkdir c:\\amiscripts"]
  }

  provisioner "file" {
    destination = "C:\\amiscripts\\"
    source      = "./ami/packer/subscription/scripts/"
  }

  provisioner "powershell" {
    inline = ["cd C:\\amiscripts", "ls", "C:\\amiscripts\\Initialize-ImageBuilder.ps1 -BucketName ${var.deployment_bucket} -Region ${var.region}"]
  }

  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted after DSC 1st run.'}\""
    restart_timeout       = "60m"
  }

  provisioner "powershell" {
    inline = ["cd C:\\amiscripts", "ls", "C:\\amiscripts\\Initialize-ImageBuilder.ps1 -BucketName ${var.deployment_bucket} -Region ${var.region}"]
  }

  // provisioner "windows-update" {
  // }

  // provisioner "windows-restart" {
  //   restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted after Windows Updates.'}\""
  //   restart_timeout       = "60m"
  // }

  provisioner "powershell" {
    inline = ["cd C:\\amiscripts", "ls", "C:\\amiscripts\\Initialize-NetOptimizationService.ps1"]
  }

  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"&amp; {Write-Output 'Machine restarted after NetOptimizationService.'}\""
    restart_timeout       = "60m"
  }

  provisioner "powershell" {
    inline = ["C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\InitializeInstance.ps1 -Schedule", "C:\\ProgramData\\Amazon\\EC2-Windows\\Launch\\Scripts\\SysprepInstance.ps1 -NoShutdown"]
  }
  
  post-processor "manifest" {
  }

}
