#NCP #도커 #실습/메모
# 0 intro
- 해당 문서는 ubuntu 22.04 LTS 환경에서 docker-compose를 이용하여 다량의 컨테이너를 올리고 실습을 진행하는 내용을 기준으로 작성하였습니다.
- docker-compose로 올릴 컨테이너는 총 4개 입니다.
- 각 단계 별 명령어 입력 - 파일 수정 내용 순으로 정렬되어 있습니다.
- 원활한 실습을 위해 C:\\Windows\\System32\\drivers\\etc 에 위치한 hosts 파일에 서버 ip 주소와 도메인 간 매핑이 필요합니다.
+ wirte & edit by [@minsubak](https://github.com/minsubak) [@DicafriO](https://github.com/DicafriO)

-------------------------------------------------------------------------------
# 1 nginx
```bash
apt install nginx -y
# install nginx

vim /etc/nginx/sites-available/default
# edit ipv6 option (disable or delete)

systemctl enable nginx
systemctl start nginx
systemctl status nginx
# systemctl work

cd /etc/nginx/
mkdir [domain] # << ssl sign key directory
vim conf.d/[domain].conf
# proxy work, [domain]: your domain
# if you are using ssl, you must change port 80 to 443 
# and clear commnet of the ssl and redirection script

systemctl restart nginx
# restart nginx

curl localhost
# test, result: nginx install success page
```

default
ipv6 리스너 주석 또는 삭제 처리
```sh
# listen [::]:80 default_server; << disable or delete ipv6 option
```

[domain].conf
```conf
# !IF USING SSL KEY, CLEAR OF THE SSL AND REDIRECTION SCRIPT!

# server { # redirection
#    listen [port];
#    server_name www.[domain] [domain];
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

upstream admin { # web LB
        server [web address]:80 max_fails=3 fail_timeout=30s;
}

server { # sending upstream to admin
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

upstream www { # web LB
        server [web address]:80 max_fails=3 fail_timeout=30s;
}

server { # sending upstrem to www
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

upstream pay { # web LB
        server [web address]:80 max_fails=3 fail_timeout=30s;
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
# 2 apache2 (WEB)
```bash
apt install apache2 -y
# install apache2

cd /etc/apache2/sites-available
vim [domain].conf
# proxy work

a2ensite [domain].conf
# site enable

a2enmod proxy_http
# proxy activate

systemctl enable apache2
systemctl start apache2
systemctl status apache2
# systemctl work
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
  ProxyPass / "http://[was address]:8080/"
  ProxyPassReverse / "http://[was address]:8080/"
</VirtualHost>

<VirtualHost *:80>
  ServerName pay.[domain]
  ProxyRequests Off
  ProxyPreserveHost On
  ProxyPass / "http://[was address]:8080/sample/"
  ProxyPassReverse / "http://[was address]:8080/sample/"
</VirtualHost>
```

-------------------------------------------------------------------------------
# 3 tomcat (WAS)

##### - tomcat 9은 spring boot 2.x.x 까지 지원 (3.x.x 이상 호환 불가)

```bash
apt install openjdk-8-jdk -y
# install jdk package

cd /usr/local/src
wget https://dlcdn.apache.org/tomcat/tomcat-9/v[version]/bin/apache-tomcat-[version].tar.gz
tar xvzf apache-tomcat-[version].tar.gz
mv apache-tomcat-[version] tomcat
# install tomcat in /usr/local/src/

useradd -M tomcat
chown tomcat:tomcat -R tomcat/
# create new user `tomcat` and change acess of directory

cd /etc/systemd/system
vim tomcat.service
# add tomcat.service to systemctl

systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat
systemctl status tomcat
# systemctl work

curl localhost:8080
# test, result: tomcat index page

cd /tmp
wget https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-j_[version]-1ubuntu22.04_all.deb
dpkg -i mysql-connector-j_[version]-1ubuntu22.04_all.deb
cp /usr/share/java/mysql-connector-j-[version].jar /usr/local/src/tomcat/lib
chown tomcat:tomcat /usr/local/src/tomcat/lib/mysql-connector-j-[version].jar
# install mysql connector/j to tomcat

cd /usr/local/src/tomcat
vim conf/context.xml
vim conf/server.xml
# apply mysql connect to tomcat and WAS clustering
# the server.xml files for [was container]s are different

mkdir -p webapps/sample/WEB-INF
cd webapps/sample
vim WEB-INF/web.xml
vim index.jsp
vim mysql_data.jsp
# add web application deployment descripter and web pages

# if mysql_data.jsp is not working, restart tomcat daemon
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
ExecStart=/usr/local/src/tomcat/bin/startup.sh
ExecStop=/usr/local/src/tomcat/bin/shutdown.sh
RestartSec=10
Restart=always
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
```

context.xml
Context 내 Resource 추가
```xml
<Context>
    <!-- <context> 내에 아래의 기능을 해당 위치에 추가 -->
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
</Context>
```

server.xml
활성화되어 있는 Connector 내용 수정, Host 내 Context 추가 필요
```xml
...
    <Connector port="8080" 
               protocol="HTTP/1.1"
               redirectPort="8443" 
               minSpareThreads="128"
               connectionTimeout="30000"
               maxThreads="2048" />
<!-- A "Connector" using the shared thread pool-->
...
...
      <Host>
        ...
        <!-- <Host></Host> 내에 <Context> 삽입 -->
        <Context docBase="/usr/local/src/tomcat/webapps/sample" path="/sample" reloadable="false" />
      </Host>
...
```

web.xml
```xml
<web-app>
<distributable/>
</web-app>
```

index.jsp
작동 여부 확인을 위한 페이지이기 때문에, 간단한 "hello, tomcat1" 같은 간단한 텍스트도 가능
```jsp
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Practice 3-Tier Acrhitecture + nginx</title>
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
        <p>Practice 3-Tier Acrhitecture + nginx</p>
        <a href="mysql_data.jsp" class="btn">Activated</a>
    </div>

</body>
</html>
```

mysql_data.jsp
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

-------------------------------------------------------------------------------
# 4 mysql (DB)

```bash
apt install mysql-server -y
# install mysql-8.0.37(default)

vim /etc/mysql/my.cnf
# edit bind-address

systemctl enable mysql
systemctl start mysql
systemctl status mysql
# systemctl work

mysql -u root
# login mysql
```
mysql 접속
```mysql
create database world;
show databases;
use world;
# check db and create new db

create table member(no int NOT NULL, t_name varchar(20), content TEXT);
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

create user '[db username]'@'%' identified by '[db password]';
GRANT ALL privileges ON world.* TO [db username]@'%';
# create new user `nsam` and apply access of world to nsam

exit
```

my.cnf
하단에 작성
```cnf
... 
[mysqld]
bind-address = 0.0.0.0
```

