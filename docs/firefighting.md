# Firefighting tools and tips

The application presently lives in a single t2.large AWS instance hosted in ap-south region. 

The application and its dependencies have been listed below
 - PostgreSQL server(9.5)
 - [Ardb](https://github.com/yinqiwen/ardb) A redis plug and play alternative for low memory environments
 - Elasticsearch (2.4.3)
 - Nginx(Open Resty)
 - Unicorn(For creating multiple Ruby processes and listening to UNIX sockets)
 
## Access to the instance

Currently, a `pem` file named as `aws-new-mumbai.pem` needs to be shared with anyone trying to access the instance.

Also an IAM profile needs to be present to access the [AWS web console](https://704247956245.signin.aws.amazon.com). Signin with your username and password and click on EC2 instances.

If you have the `pem` file, the instance can be accessed using

```bash
ssh -i ~/.ssh/aws-new-mumbai.pem ec2-user@13.126.50.230
```

The home folder has a file named as `instance_init.sh`.

To restart all processes simple run


```bash
cd ~/
./instance_init.sh
```

To just restart the unicorn process(loads the new ruby application code), simply run

```bash
cd ~/uk-property
./unicorn_init.sh
```

### Instance data info

There are two volumes mounted on the instance

 - `/` (8 GB..OS, application code..This dies when an instance is terminated
 - `/mnt3/`(100 GB) (Postgres data, Elastic data and Ardb data..All reside here)
 - `/mnt3/postgres_data` contains all the existing tables of PostgreSQL
 - `/mnt3/elasticsearch` contains all the data related to Elastic
 - `/mnt3/ardb` contains all the data for udprns and ardb installation code
 - `/mnt3/royal.csv` (Royal mail property data)
 - `/mnt3/flat_transactions.csv` (All the property historical transactions)

Its also possible to create a new instance with the same application and data as the previous one. However the process is a bit involved.

### Creating a new copy instance to the original one

  - Please create copies of the disk volume `/mnt3` and `/`.
  - Create a new instance in any region and attach those volumes to the instance.
  - Mount those volumes and we can have our data and application back.
  - Install Elasticsearch(2.4.3) and PostgreSQL(9.5)
  - Install Nginx
  - The original nginx conf resided at the location `/usr/local/openresty/nginx/conf/nginx.conf`. Copy this `conf` file to the relevant nginx conf directory.
  - Ardb installation lives in the `mnt3` directory (In future, we'll move to Redis on availability of higher memory instances)
  - Open `sudo vim /var/lib/pgsql94/data/postgresql.conf` and tweak the `data_directory` to the location containing the backed up postgres data.
  - Open `sudo vim /etc/elasticsearch/elasticsearch.yml` and tweak the setting `path.data` and `path.logs` to the relevant data and log location.
  - Start the ardb server(Redis)
    ```bash
    cd /mnt3/ardb/
    ./ardb-server
    ```
  - You can change ardb's settings by changing the value of the setting `data-dir` located inside the file `/mnt3/ardb/ardb.conf`
  - After all the data locations have been configured correctly, simply restart all the processes by running `instance_init.sh`
    ```bash
    ./instance_init.sh ## Location of the file instance_init.sh
    ```

And access the following apis

1) Elasticsearch health monitoring
```bash
curl locahost:9200
```

2) Rails apis
```bash
curl localhost
```
 If everything seems fine, the instance copy has completed successfully.
 

