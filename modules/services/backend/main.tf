resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elb" {
  name = "${var.cluster_name}-elb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.elb.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.elb.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "ap-northeast-2"
  }
}

resource "aws_launch_configuration" "w-sharing-example" {
  image_id        = "ami-0b1d3b1941f23c7d5"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.instance.id]

  user_data = templatefile("${path.module}/user-data.tpl", {
    server_port = var.server_port,
    db_address  = data.terraform_remote_state.db.outputs.address,
    db_port     = data.terraform_remote_state.db.outputs.port,
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "w-sharing-example" {
  launch_configuration = aws_launch_configuration.w-sharing-example.id
  availability_zones   = data.aws_availability_zones.all.names

  load_balancers    = [aws_elb.w-sharing-example.name]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }
}

resource "aws_elb" "w-sharing-example" {
  name               = "${var.cluster_name}-elb"
  availability_zones = data.aws_availability_zones.all.names
  security_groups    = [aws_security_group.elb.id]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:${var.server_port}/"
  }
}
