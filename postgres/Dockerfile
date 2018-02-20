FROM postgres:10
COPY uint.so .
COPY uint--0.sql .
COPY uint.control .
RUN /usr/bin/install -c -m 755  uint.so 'usr/lib/postgresql/10/lib/uint.so'
RUN /usr/bin/install -c -m 644  uint.control '/usr/share/postgresql/10/extension/'
RUN /usr/bin/install -c -m 644  uint--0.sql '/usr/share/postgresql/10/extension/'
COPY install_extension.sql /docker-entrypoint-initdb.d

