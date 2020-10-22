CREATE TABLE USER (ID BIGINT NOT NULL, EMAIL VARCHAR(255), FULLNAME VARCHAR(255), PASSWORD VARCHAR(255), PRIMARY KEY (ID));
CREATE TABLE POST (ID BIGINT NOT NULL, CONTENT LONGTEXT, CREATED DATETIME, TITLE VARCHAR(255), USER_ID BIGINT, PRIMARY KEY (ID));
CREATE TABLE COMMENT (ID BIGINT NOT NULL, AUTHOR VARCHAR(255), CONTENT LONGTEXT, post_id BIGINT, PRIMARY KEY (ID));
ALTER TABLE POST ADD CONSTRAINT FK_POST_USER_ID FOREIGN KEY (USER_ID) REFERENCES USER (ID);
ALTER TABLE COMMENT ADD CONSTRAINT FK_COMMENT_post_id FOREIGN KEY (post_id) REFERENCES POST (ID);
CREATE TABLE SEQUENCE (SEQ_NAME VARCHAR(50) NOT NULL, SEQ_COUNT DECIMAL(38), PRIMARY KEY (SEQ_NAME));

INSERT INTO SEQUENCE (SEQ_NAME, SEQ_COUNT) VALUES ('SEQ_GEN', 1);
INSERT INTO USER (`ID`,`EMAIL`,`FULLNAME`,`PASSWORD`) VALUES (1,'abc@abc.com','Rohit Bajaj','password');
INSERT INTO POST (`ID`,`CONTENT`,`CREATED`,`TITLE`,`USER_ID`) VALUES (2,'d d. v v wd. ','2020-10-12 05:43:29','Just having fun',1);
