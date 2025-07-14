#NCP #도커 #실습/메모
# 0 intro
- 해당 문서는 ubuntu 22.04 LTS 환경에서 docker-compose를 이용하여 다량의 컨테이너를 올리고 실습을 진행하는 내용을 기준으로 작성하였습니다.
- docker-compose로 올릴 컨테이너는 총 7개 입니다.
- 각 단계 별 명령어 입력 - 파일 수정 내용 순으로 정렬되어 있습니다.
- 원활한 실습을 위해 C:\\Windows\\System32\\drivers\\etc 에 위치한 hosts 파일에 서버 ip 주소와 도메인 간 매핑이 필요합니다.
+ wirte & edit by [@minsubak](https://github.com/minsubak) [@DicafriO](https://github.com/DicafriO)

------------------------------------------------------------------------------------
# 1 nginx (external LB)
##### - NCP환경일 경우, Load Balancer 기능을 사용하기에 생략한다.
```bash
apt install nginx -y
# nginx 설치

vim /etc/nginx/sites-available/default
# ipv6 리스너 비활성화 또는 제거
# 만약, 443포트(SSL 인증서)를 사용할 경우, 관련 옵션 활성화 필요

systemctl enable nginx
systemctl start nginx
systemctl status nginx
# 서비스 데몬 작업

cd /etc/nginx
mkdir [domain] # SSL 인증키 보관 디렉토리
vim conf.d/[domain].conf
# 프록시 작업, [domain]: 사용할 도메인 입력
# 만약 443포트(SSL 인증서)를 사용할 경우, 80 > 443 수정 필요
# 그리고 443포트(SSL 기능)의 주석 제거 필요

systemctl restart nginx
# nginx 서비스 재시작

curl localhost
# 테스트(결과: nginx 기본 페이지)
```

default
```sh
# listen [::]:80 default_server; << 주석으로 처리 또는 제거
```

[domain].conf
```conf
# server { # redirection
#    listen [port];
#    server_name www.[domain];
#    return 301 [http | https]://$server_name$request_uri;
#}
#
#server { # redirection
#    listen [port];
#    server_name admin.[domain];
#    return 301 [http | https]://$server_name$request_uri;
#}
#
#server { # redirection
#    listen [port];
#    server_name pay.[domain];
#    return 301 [http | https]://$server_name$request_uri;
#}

upstream admin { # WEB LB
       server [web address1]:80 max_fails=3 fail_timeout=30s;
       server [web address2]:80 max_fails=3 fail_timeout=30s;
}

server { # sendine upstream to admin
        listen 80;
        #ssl on;
        server_name admin.[domain];
        #ssl_certificate /etc/nginx/[domain]/fullchain.pem;
        #ssl_certificate_key /etc/nginx/[domain]/privkey.pem;
        location / {
                   proxy_set_header X-Forwarded-For $remote_addr;
                   proxy_set_header X-Forwarded-Proto $scheme;
                   proxy_set_header Host $http_host;
                   proxy_pass http://admin;
        }
}

upstream www { # WEB LB
       server [web address1]:80 max_fails=3 fail_timeout=30s;
       server [web address2]:80 max_fails=3 fail_timeout=30s;
}

server { # sending upstream to www
		listen 80;
        #ssl on;
        server_name www.[domain];
        #ssl_certificate /etc/nginx/[domain]/fullchain.pem;
        #ssl_certificate_key /etc/nginx/[domain]/privkey.pem;
        location / {
                   proxy_set_header X-Forwarded-For $remote_addr;
                   proxy_set_header X-Forwarded-Proto $scheme;
                   proxy_set_header Host $http_host;
                   proxy_pass http://www;
        }
}

upstream pay { # WEB LB
       server [web address1]:80 max_fails=3 fail_timeout=30s;
       server [web address2]:80 max_fails=3 fail_timeout=30s;
}

server { # sending upstream to pay
        listen 80;
        #ssl on;
        server_name pay.[domain];
        #ssl_certificate /etc/nginx/[domain]/fullchain.pem;
        #ssl_certificate_key /etc/nginx/[domain]/privkey.pem;
        location / {
                   proxy_set_header X-Forwarded-For $remote_addr;
                   proxy_set_header X-Forwarded-Proto $scheme;
                   proxy_set_header Host $http_host;
                   proxy_pass http://pay;
        }
}
```

-------------------------------------------------------------------------------

# 2 apache (WEB)
web container 두 개 모두 동일하게 설정해야 한다.
```bash
apt install apache2 -y
# apache2 설치

cd /etc/apache2/sites-available
vim [domain].conf
# 프록시 작업

a2ensite [domain].conf
# [domain].conf 허용

a2enmod proxy_http
# 프록시 허용

systemctl enable apache2
systemctl start apache2
systemctl status apache2
# 서비스 데몬 작업
```

[domain].conf
```conf
<VirtualHost *:80>
  ServerName www.[domain]
</VirtualHost>

<VirtualHost *:80>
  ServerName admin.[domain]
  ProxyRequests Off
  ProxyPreserveHost On
  ProxyPass / "http://[internal lb address]/"
  ProxyPassReverse / "http://[internal lb address]/"
</VirtualHost>

<VirtualHost *:80>
  ServerName pay.[domain]
  ProxyRequests Off
  ProxyPreserveHost On
  ProxyPass / "http://[internal lb address]/sample/"
  ProxyPassReverse / "http://[internal lb address]/sample/"
</VirtualHost>
```

-------------------------------------------------------------------------------
# 3 nginx (internal LB)
##### - NCP환경일 경우, Load Balancer 기능을 사용하기에 이 과정을 생략한다.
```bash
apt install nginx -y
# nginx 설치

vim /etc/nginx/sites-available/default
# ipv6 리스너 비활성화 또는 제거

systemctl enable nginx
systemctl start nginx
systemctl status nginx
# 서비스 데몬 작업

cd /etc/nginx
vim conf.d/[domain].conf
# 프록시 작업, [domain]: 사용할 도메인 입력

systemctl restart nginx
# nginx 서비스 재시작

curl localhost
# 테스트(결과: nginx 기본 페이지)
```

[domain].conf
```conf
upstream pay { # WAS LB
       # ip_hash; # hold specific tomcat conatienr
       server [was address1]:8080 max_fails=3 fail_timeout=30s;
       server [was address2]:8080 max_fails=3 fail_timeout=30s;
}

server { # sending upstream to pay
        listen 80;
        server_name pay.[domain];
        location / {
                   proxy_set_header X-Forwarded-For $remote_addr;
                   proxy_set_header X-Forwarded-Proto $scheme;
                   proxy_set_header Host $http_host;
				   proxy_pass http://pay;
        }
}

upstream admin { # WAS LB
       # ip_hash;
       server [was address1]:8080 max_fails=3 fail_timeout=30s;
       server [was address2]:8080 max_fails=3 fail_timeout=30s;
}

server {
        listen 80;
        server_name admin.[domain];
        location / {
                   proxy_set_header X-Forwarded-For $remote_addr;
                   proxy_set_header X-Forwarded-Proto $scheme;
                   proxy_set_header Host $http_host;
				   proxy_pass http://admin;
        }
}
```

------------------------------------------------------------------------------------
# 4 tomcat (WAS)
##### - was container 두 개 모두 설정해야 한다.
##### - tomcat 9은 spring boot 2.x.x 까지 지원 (3.x.x 이상 호환 불가)
```bash
apt install openjdk-8-jdk -y
# 자바 개발 킷 설치 (버전 8~11 호환 확인)

cd /usr/local/src
wget https://dlcdn.apache.org/tomcat/tomcat-9/v[version]/bin/apache-tomcat-[version].tar.gz
tar xvzf apache-tomcat-[version].tar.gz
mv apache-tomcat-[version] tomcat
# /usr/local/src/ 위치에 tomcat 설치

useradd -M tomcat
chown tomcat:tomcat -R tomcat/
# tomcat 유저를 생성 후, tomcat 디렉토리 권환을 위임

cd /etc/systemd/system
vim tomcat.service
# tomcat을 서비스 데몬으로 올리기 위한 파일 작성

systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat
systemctl status tomcat
# 서비스 데몬 작업

curl localhost:8080
# 테스트 (결과: tomcat 기본 페이지)

cd /tmp
wget https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-j_[version]-1ubuntu22.04_all.deb
dpkg -i mysql-connector-j_[version]-1ubuntu22.04_all.deb
cp /usr/share/java/mysql-connector-j-[version].jar /usr/local/src/tomcat/lib
chown tomcat:tomcat /usr/local/src/tomcat/lib/mysql-connector-j-[version].jar
# MySQL과 통신을 도와주는 MySQL Conncector/J 설치

cd /usr/local/src/tomcat
vim conf/context.xml
vim conf/server.xml
# tomcat과 MySQL 간 통신을 위한 데이터와 클러스터링 옵션 작성
# !server.xml 파일 내 [was container]의 번호값에 유의할 것!

mkdir -p webapps/sample/WEB-INF
cd webapps/sample
vim WEB-INF/web.xml
vim index.jsp
vim mysql_data.jsp
# 웹 페이지와 클러스팅 기능을 사용을 위한 구성 파일 작성

systemctl restart tomcat
# tomcat 재시작
```

tomcat.service
```service
[Unit]
Description=tomcat 9
After=network.target syslog.target

[Service]
Type=forking
Environment="/usr/local/src/tomcat"
User=tomcat
Group=tomcat
ExecStart= /usr/local/src/tomcat/bin/startup.sh
ExecStop= /usr/local/src/tomcat/bin/shutdown.sh
RestartSec=10
Restart=always
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
```

context.xml
context 내에 추가
```xml
    <Resource name="jdbc/mysql"
              auth="Container"
              type="javax.sql.DataSource"
              username="[db username]"
              password="[db password]"
              driverClassName="com.mysql.cj.jdbc.Driver"
              url="jdbc:mysql://[db address]"
              maxTotal="50"
              maxIdle="20"
              maxWaitMillis="20000"/>
```

server.xml (was1)
```xml
        <!-- clustering -->
        <Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster" channelSendOptions="8" channelStartOptions="3">
                <Manager className="org.apache.catalina.ha.session.DeltaManager" expireSessionsOnShutdown="false" notifyListenersOnReplication="true"/>
                <Channel className="org.apache.catalina.tribes.group.GroupChannel">
                        <Sender className="org.apache.catalina.tribes.transport.ReplicationTransmitter">
                                <Transport className="org.apache.catalina.tribes.transport.nio.PooledParallelSender" />
                        </Sender>
                        <Receiver className="org.apache.catalina.tribes.transport.nio.NioReceiver"
                        address="[was address1]"
                        port="4055"
                        autoBind="0"
                        selectorTimeout="5000"
                        maxThreads="6"/>

                        <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpPingInterceptor" staticOnly="true"/>
                        <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpFailureDetector" />
                        <Interceptor className="org.apache.catalina.tribes.group.interceptors.StaticMembershipInterceptor">
                        <Member
                                className="org.apache.catalina.tribes.membership.StaticMember"
                                port="4055"
                                host="[was address2]"
                                uniqueId="{0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2}"
                        />
                        </Interceptor>
                        <Interceptor className="org.apache.catalina.tribes.group.interceptors.MessageDispatchInterceptor"/>
                </Channel>

                <Valve className="org.apache.catalina.ha.tcp.ReplicationValve" filter=".*\.gif;.*\.js;.*\.jpg;.*\.png;.*\.htm;.*\.html;.*\.css;.*\.txt;" />
                <Valve className="org.apache.catalina.ha.session.JvmRouteBinderValve"/>
                <ClusterListener className="org.apache.catalina.ha.session.ClusterSessionListener" />
        </Cluster>
        <!-- clustering  -->
```

server.xml (was2)
```xml
        <!-- clustering -->
        <Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster" channelSendOptions="8" channelStartOptions="3">
                <Manager className="org.apache.catalina.ha.session.DeltaManager" expireSessionsOnShutdown="false" notifyListenersOnReplication="true"/>
                <Channel className="org.apache.catalina.tribes.group.GroupChannel">
                        <Sender className="org.apache.catalina.tribes.transport.ReplicationTransmitter">
                                <Transport className="org.apache.catalina.tribes.transport.nio.PooledParallelSender" />
                        </Sender>
                        <Receiver className="org.apache.catalina.tribes.transport.nio.NioReceiver"
                        address="[was address2]"
                        port="4055"
                        autoBind="0"
                        selectorTimeout="5000"
                        maxThreads="6"/>

                        <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpPingInterceptor" staticOnly="true"/>
                        <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpFailureDetector" />
                        <Interceptor className="org.apache.catalina.tribes.group.interceptors.StaticMembershipInterceptor">
                        <Member
                                className="org.apache.catalina.tribes.membership.StaticMember"
                                port="4055"
                                host="[was address1]"
                                uniqueId="{0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1}"
                        />
                        </Interceptor>
                        <Interceptor className="org.apache.catalina.tribes.group.interceptors.MessageDispatchInterceptor"/>
                </Channel>

                <Valve className="org.apache.catalina.ha.tcp.ReplicationValve" filter=".*\.gif;.*\.js;.*\.jpg;.*\.png;.*\.htm;.*\.html;.*\.css;.*\.txt;" />
                <Valve className="org.apache.catalina.ha.session.JvmRouteBinderValve"/>
                <ClusterListener className="org.apache.catalina.ha.session.ClusterSessionListener" />
        </Cluster>
        <!-- clustering  -->
```

web.xml
```xml
<web-app>
<distributable/>
</web-app>
```

index.jsp
```jsp
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Practice 3-Tier Acrhitecture Dualization</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f0f0f0;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        .container {
            text-align: center;
        }
        h1 {
            color: #333;
            margin-bottom: 20px;
        }
        p {
            color: #666;
            margin-bottom: 30px;
        }
        a {
            text-decoration: none;
            color: #fff;
            background-color: #007bff;
            padding: 10px 20px;
            border-radius: 5px;
            transition: background-color 0.3s ease;
        }
        a:hover {
            background-color: #0056b3;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to My Website by Apache tomcat</h1>
        <p>Practice 3-Tier Dualization</p>
        <a href="mysql_data.jsp" class="btn">Activated</a>
    </div>

</body>
</html>
```

mysql_data_jsp
```jsp
<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ page import="javax.sql.*" %>
<%@ page import="javax.naming.*" %>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Database Connection</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
        }
        .success {
            color: green;
            font-weight: bold;
        }
        .failure {
            color: red;
            font-weight: bold;
        }
        .result-box {
            margin-top: 20px;
            padding: 15px;
            border: 2px solid #000;
            border-radius: 5px;
            background-color: #f9f9f9;
        }
        .result {
            width: 100%;
            border-collapse: collapse;
        }
        .result, .result th, .result td {
            border: 1px solid #000;
        }
        .result th, .result td {
            padding: 8px;
            text-align: left;
        }
    </style>
</head>
<body>
    <h1>Database Connection Results</h1>
    <%
    Connection conn = null;

    try {
        // JNDI
        Context init = new InitialContext();
        DataSource ds = (DataSource) init.lookup("java:comp/env/jdbc/mysql");
        conn = ds.getConnection();
    %>
    <div class="success">JNDI Connection Success!!!</div>
    <div class="result-box">
        <table class="result">
            <tr><th>ID</th><th>Name</th><th>Email</th></tr>
        <%
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT * FROM world.member");
            
            while (rs.next()) {
        %>
            <tr>
                <td><%= rs.getString(1) %></td>
                <td><%= rs.getString(2) %></td>
                <td><%= rs.getString(3) %></td>
            </tr>
        <%
            }
            
            rs.close();
            stmt.close();
        %>
        </table>
    </div>
    <%
    } catch (Exception e) {
    %>
    <div class="failure">JNDI Connection Failure!!!</div>
    <div class="result-box"><pre><%= e.toString() %></pre></div>
    <%
    }

    try {
        // DriverManager
        String DB_URL = "jdbc:mysql://[db address]:3306/world";
        String DB_USER = "[db username]";
        String DB_PASSWORD = "[db password]";
        
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
    %>
    <div class="success">DriverManager Connection Success!!!</div>
    <div class="result-box">
        <table class="result">
            <tr><th>ID</th><th>Name</th><th>Email</th></tr>
        <%
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT * FROM world.member");
            
            while (rs.next()) {
        %>
            <tr>
                <td><%= rs.getString(1) %></td>
                <td><%= rs.getString(2) %></td>
                <td><%= rs.getString(3) %></td>
            </tr>
        <%
            }
            
            rs.close();
            stmt.close();
        %>
        </table>
    </div>
    <%
    } catch (Exception e) {
    %>
    <div class="failure">DriverManager Connection Failure!!!</div>
    <div class="result-box"><pre><%= e.toString() %></pre></div>
    <%
    } finally {
        try {
            if (conn != null) conn.close();
        } catch (SQLException e) {
    %>
    <div class="failure">Error closing connection: <%= e.getMessage() %></div>
    <%
        }
    }
    %>
</body>
</html>

```

------------------------------------------------------------------------------------
# 5 MySQL (DB)
docker환경일 경우 5.1을 NCP환경일 경우 5.2 과정을 진행하며, host(bastion) 서버에 설치하여 DB서버에 원격으로 연결한다.
[공식가이드](https://guide.ncloud-docs.com/docs/clouddbformysql-start)
## 5.1 docker
```bash
apt install mysql-server -y
# MySQL 설치 (default: 8.0.37)

vim /etc/mysql/my.cnf
# my.cnf 수정

systemctl enable mysql
systemctl start mysql
systemctl status mysql
# 서비스 데몬 작업

mysql -u root
# MySQL에 접속
```
## 5.2 NCP
```bash
mysql -h [db address] -u [db_username] -p --port 3306
# NCP에서 CDBM에 연결하는 방법
```

MySQL 작업
```mysql
create database world;
show databases;
use world;
# check db and create new db

create table member(no int not null, t_name varchar(20), content text);
# create new table `member`

insert into member values('1', 'kkk', 'lee');
insert into member values('2', 'aaa', 'kim');
insert into member values('3', 'bbb', 'back');
insert into member values('4', 'ccc', 'boo');
insert into member values('5', 'ddd', 'hooo');
insert into member values('6', 'eee', 'ha');
# insert new data

select * from member;
# print all memeber table

create user [db username]@'%' identified by '[db password]';
grant all privileges on world.* to [db username]@'%';
# create new user `nsam` and apply access of world to nsam

exit
```

my.cnf
```cnf
[mysqld]
bind-address = 0.0.0.0
```