curl -XPOST "http://ec2-52-38-219-110.us-west-2.compute.amazonaws.com/addresses/address/_search?scroll=30m" -d'{"size" : 5000,"filter": {"term": {"county": "Herefordshire"}}}' >a.txt

curl -XDELETE "http://localhost:9200/_search/scroll" -d'{"scroll_id" : ["cXVlcnlUaGVuRmV0Y2g7NTs3MTk2OkNvamwtRG1oUnU2cl9GbC0zSHpFcXc7NzE5NzpDb2psLURtaFJ1NnJfRmwtM0h6RXF3OzcxOTg6Q29qbC1EbWhSdTZyX0ZsLTNIekVxdzs3MTk5OkNvamwtRG1oUnU2cl9GbC0zSHpFcXc7NzIwMDpDb2psLURtaFJ1NnJfRmwtM0h6RXF3OzA7"]}'