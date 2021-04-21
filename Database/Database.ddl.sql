-- create database mydb;
use heroku_cef71ea1a512a1b;
-- use iitilrc;
create database iitilrc;
set sql_safe_updates = 0;
-- drop database iitilrc;

/*
Entities
1. Account
2. Users
3. Librarian
4. Reviews
5. Books
6. Author
7. Shelf
8. Book-Copies
9. Hold-Requests
10. Rating
11. Friend-Requests
*/

-- Entities
create table account(
accountID int auto_increment unique not null,
password varchar(200),
accountType varchar(20),
email varchar(70),
primary key(email)
);
-- drop table account;

create table user(
userID int,
name varchar(50),
email varchar(70),
address varchar(500),
unpaidFines int,
primary key(userID),
foreign key(userID) references account(accountID)
);
-- drop table user;

create table librarian(
librarianID int,
name varchar(50),
address varchar(500),
email varchar(70),
primary key(librarianID),
foreign key(librarianID) references account(accountID) on delete cascade
);
-- drop table librarian;
-- insert into account(password, accountType, email) values('abc', 'librarian', 'a@b.com');
-- insert into librarian values(14, 'PC', 'xyz', 'a@b.com');

create table book(
ISBN varchar(15),
title varchar(100),
yearOfPublication int,
totalCopies int,
noOfCopiesOnShelf int,
authors varchar(200),
category varchar(20),
image varchar(1000),
primary key(ISBN)
);
-- drop table book;

create table review(
reviewID int auto_increment,
reviewText varchar(500),
userID int,
ISBN varchar(15),
primary key(reviewID),
foreign key(userID) references user(userID) on delete cascade,
foreign key(ISBN) references book(ISBN) on delete cascade
);
-- drop table review;

create table shelf(
shelfID int,
capacity int,
primary key(shelfID)
);
-- drop table shelf;

create table bookCopies(
ISBN varchar(15),
copyID int,
bookStatus varchar(20),
dueDate date,
shelfID int,
primary key(ISBN, copyID),
foreign key(ISBN) references book(ISBN),
foreign key(shelfID) references shelf(shelfID)
);
-- drop table bookCopies

create table holdRequest(
requestID int auto_increment unique not null,
ISBN varchar(15),
userID int,
holdTime datetime,
primary key(ISBN, userID),
foreign key(ISBN) references book(ISBN) on delete cascade,
foreign key(userID) references user(userID) on delete cascade
);
-- drop table holdRequest

create table rating(
ratingID int auto_increment,
ISBN varchar(15),
userID int,
rating int,
primary key(ratingID),
foreign key(ISBN) references book(ISBN) on delete cascade,
foreign key(userID) references user(userID) on delete set null
);
-- drop table rating

create table friendRequest(
requesterID int,
requestedID int,
primary key(requesterID, requestedID),
foreign key(requesterID) references user(userID) on delete cascade,
foreign key(requestedID) references user(userID) on delete cascade
);
-- drop table friendRequest

/*
Relationships
1. Friend-User relation
2. User-BookCopies   
3. Reading-List relation 
4. Book-Author relation
*/

-- Relations
create table friendUser(
userID int,
friendID int,
primary key(userID, friendID),
foreign key(userID) references user(userID) on delete cascade,
foreign key(userID) references user(userID) on delete cascade
);
-- drop table friendUser

create table bookCopiesUser(
ISBN varchar(15),
copyID int,
userID int,
action varchar(20),
primary key(ISBN, copyID, userID),
foreign key(ISBN) references bookCopies(ISBN),
foreign key(userID) references user(userID)
);
-- drop table bookCopiesUser

create table readingList(
ISBN varchar(15),
userID int,
status varchar(20),
favourite varchar(3) default 'NO',
primary key(ISBN, userID),
foreign key(ISBN) references book(ISBN) on delete cascade,
foreign key(userID) references user(userID) on delete cascade
);
-- drop table readingList

create table feedback(
feedbackID int auto_increment not null,
name varchar(50),
email varchar(70),
phone varchar(13),
feedback varchar(1000),
primary key(feedbackID)
);
-- drop table feedback

