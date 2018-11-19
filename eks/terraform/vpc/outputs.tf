output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "subnets" {
  value = ["${aws_subnet.main}"]
}

output "gateway_id" {
  value = "${aws_internet_gateway.main.id}"
}

output "route_table_id" {
  value = "${aws_route_table.main.id}"
}
