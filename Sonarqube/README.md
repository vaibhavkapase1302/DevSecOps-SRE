### Documentation: **Checking SonarQube Database, Logging in, Configurations, Backup, and S3 Upload**

This document outlines the steps to:

1. **Identify the database running on SonarQube**.
2. **Log in to the database**.
3. **Check the configuration** and validate the database.
4. **Take a backup of the database**.
5. **Move the backup to Amazon S3**.

---

### **1. Identify the Database Running on SonarQube**

SonarQube supports multiple database types (H2, PostgreSQL, MySQL, Oracle, etc.). To determine which database SonarQube is using, follow these steps:

#### **Step 1: Check SonarQube Database Configuration**

1. **Locate SonarQube Configuration File**:
   
   The database configuration for SonarQube is typically located in the `sonar.properties` file:
   
   ```bash
   /opt/sonarqube/conf/sonar.properties
   ```

2. **Check for Database Configuration**:
   
   Open `sonar.properties` using any text editor to check the configuration:

   ```bash
   sudo nano /opt/sonarqube/conf/sonar.properties
   ```

   Look for the following lines:

   - **For H2 Database** (default in SonarQube):

     ```properties
     # For H2 database
     sonar.jdbc.url=jdbc:h2:tcp://localhost:9092/sonar
     sonar.jdbc.username=sonar
     sonar.jdbc.password=sonar
     ```

   - **For PostgreSQL**:

     ```properties
     # For PostgreSQL database
     sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonar
     sonar.jdbc.username=sonar
     sonar.jdbc.password=sonar
     ```

   - **For MySQL**:

     ```properties
     # For MySQL database
     sonar.jdbc.url=jdbc:mysql://localhost:3306/sonar
     sonar.jdbc.username=sonar
     sonar.jdbc.password=sonar
     ```

   - **For Oracle**:

     ```properties
     # For Oracle database
     sonar.jdbc.url=jdbc:oracle:thin:@localhost:1521:sonar
     sonar.jdbc.username=sonar
     sonar.jdbc.password=sonar
     ```

3. **Identify the Database**:
   - The **JDBC URL** will indicate which database SonarQube is using (H2, PostgreSQL, MySQL, etc.).
   - If the **JDBC URL** contains `h2`, it means SonarQube is using the **H2 database** (default).
   - If the **JDBC URL** contains `postgresql`, `mysql`, or `oracle`, it indicates the respective database.

---

### **2. Log in to the Database**

Once you've identified the database SonarQube is using, log in using the appropriate client.

#### **For H2 Database**

1. **Use H2 Shell** (command-line interface) to connect to the database:

   ```bash
   java -cp h2-1.4.199.jar org.h2.tools.Shell -url jdbc:h2:tcp://127.0.0.1:9092/sonar -user sonar -password sonar
   ```

#### **For PostgreSQL Database**

1. **Use `psql` command-line tool** to connect:

   ```bash
   sudo -u postgres psql -h localhost -U sonar -d sonar
   ```

#### **For MySQL Database**

1. **Use `mysql` command-line tool** to connect:

   ```bash
   mysql -u sonar -p -h localhost sonar
   ```

#### **For Oracle Database**

1. **Use `sqlplus` command-line tool** to connect:

   ```bash
   sqlplus sonar/sonar@//localhost:1521/sonar
   ```

---

### **3. Check Database Configuration**

Once connected to the database, you can run queries to verify the configuration.

#### **For H2 Database**

- **List all tables**:

  ```sql
  \dt
  ```

- **Show database schema**:

  ```sql
  SELECT * FROM INFORMATION_SCHEMA.SCHEMATA;
  ```

- **Check the status of the SonarQube schema**:

  ```sql
  SELECT * FROM public.sonar_properties;
  ```

#### **For PostgreSQL Database**

- **List all tables**:

  ```sql
  \dt
  ```

- **Show database schema**:

  ```sql
  SELECT schema_name FROM information_schema.schemata;
  ```

- **Check the SonarQube configuration**:

  ```sql
  SELECT * FROM sonar_properties;
  ```

#### **For MySQL Database**

- **List all tables**:

  ```sql
  SHOW TABLES;
  ```

- **Show database schema**:

  ```sql
  SHOW DATABASES;
  ```

- **Check SonarQube configurations**:

  ```sql
  SELECT * FROM sonar_properties;
  ```

#### **For Oracle Database**

- **List all tables**:

  ```sql
  SELECT table_name FROM all_tables;
  ```

- **Show database schema**:

  ```sql
  SELECT username FROM dba_users;
  ```

- **Check SonarQube configurations**:

  ```sql
  SELECT * FROM sonar_properties;
  ```

---

### **4. Take a Backup of the Database**

After confirming the configuration and ensuring everything is correct, proceed with taking a backup of the database.

#### **For H2 Database**

1. **Stop SonarQube** (optional but recommended to avoid issues with backup consistency):

   ```bash
   sudo systemctl stop sonarqube
   ```

2. **Run the H2 Backup Command**:

   ```bash
   java -cp h2-1.4.199.jar org.h2.tools.Backup -dir /opt/sonarqube/backups -file sonar_backup.zip -quiet
   ```

3. **Verify the Backup**:

   Check the backup directory (`/opt/sonarqube/backups/`) for the backup file (`sonar_backup.zip`).

#### **For PostgreSQL Database**

1. **Stop SonarQube** (optional but recommended):

   ```bash
   sudo systemctl stop sonarqube
   ```

2. **Run the PostgreSQL Backup Command**:

   ```bash
   sudo -u postgres pg_dump sonar > /opt/sonarqube/backups/sonar_backup.sql
   ```

3. **Verify the Backup**:

   Check the backup directory (`/opt/sonarqube/backups/`) for the backup file (`sonar_backup.sql`).

#### **For MySQL Database**

1. **Stop SonarQube** (optional but recommended):

   ```bash
   sudo systemctl stop sonarqube
   ```

2. **Run the MySQL Backup Command**:

   ```bash
   mysqldump -u sonar -p sonar > /opt/sonarqube/backups/sonar_backup.sql
   ```

3. **Verify the Backup**:

   Check the backup directory (`/opt/sonarqube/backups/`) for the backup file (`sonar_backup.sql`).

#### **For Oracle Database**

1. **Stop SonarQube** (optional but recommended):

   ```bash
   sudo systemctl stop sonarqube
   ```

2. **Run the Oracle Backup Command**:

   Use Oracle's `exp` command to export the database:

   ```bash
   exp sonar/sonar@localhost:1521/sonar file=/opt/sonarqube/backups/sonar_backup.dmp
   ```

3. **Verify the Backup**:

   Check the backup directory (`/opt/sonarqube/backups/`) for the backup file (`sonar_backup.dmp`).

---

### **5. Move the Backup to Amazon S3**

After taking the backup, you can upload it to Amazon S3 for secure storage.

#### **Step 1: Install and Configure AWS CLI**

If AWS CLI is not installed, install it:

```bash
sudo apt-get install awscli
```

Configure AWS CLI with your AWS credentials:

```bash
aws configure
```

Provide the **AWS Access Key ID**, **Secret Access Key**, **region**, and **output format**.

#### **Step 2: Upload the Backup to S3**

Use the `aws s3 cp` command to upload the backup file to S3. For example, to upload the backup:

```bash
aws s3 cp /opt/sonarqube/backups/sonar_backup.zip s3://your-bucket-name/sonar_backups/
```

Replace `/opt/sonarqube/backups/sonar_backup.zip` with the actual backup file path and `your-bucket-name` with your S3 bucket name.

#### **Step 3: Verify the Upload**

Verify that the backup file was successfully uploaded to S3:

```bash
aws s3 ls s3://your-bucket-name/sonar_backups/
```

---

### **Conclusion**

With the steps outlined in this document, you should be able to:

1. Identify the database SonarQube is using.
2. Log in to the database.
3. Check its configuration.
4. Take a backup of the database.
5. Upload the backup to Amazon S3 for safe storage.

## how to pass sonar token in pipeline jenkins

https://stackoverflow.com/questions/50646519/sonarqube-jenkins-asks-for-login-and-password

https://stackoverflow.com/questions/78471082/jenkins-credentials-for-sonarqube-token-wont-update/79402231#79402231
