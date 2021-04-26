-- All procedures together

delimiter //
create procedure addBook(
    in ISBN varchar(15),
    in title varchar(100),
    in yearOfPublication int,
    in noOfCopies int,
    in authors varchar(200),
    in category varchar(20),
    in image varchar(1000),
    in shelfID int,
    out did int,
    out inv int
)
b: begin
declare x int;
declare shelfBooks int;
declare shelfCapacity int;
declare exit handler for 1062
begin
set did=1;
end;
select count(bookCopies.bookStatus) into shelfBooks from bookCopies 
where bookCopies.bookStatus = 'shelf' and bookCopies.shelfID = shelfID;
select shelf.capacity into shelfCapacity from shelf where shelf.shelfID = shelfID;
if((shelfCapacity - shelfBooks) < noOfCopies) then
    set inv=1;
    leave b;
end if;
insert into book values(ISBN, title, yearOfPublication, noOfCopies, noOfCopies, authors, category, image);
set x = 1;
a:loop
    if(x > noOfCopies) then
        leave a;
    end if;
    insert into bookCopies values(ISBN, x, 'shelf', NULL, shelfID);
    set x = x + 1;
end loop;
end //
delimiter ;

delimiter //
create procedure approveFriendRequest(
	in userID int,
	in requesterID int
)
begin
insert into friendUser values(userID, requesterID);
insert into friendUser values(requesterID, userID);
delete from friendRequest where friendRequest.requestedID = userID and friendRequest.requesterID = requesterID;
end //
delimiter ;

delimiter //
create procedure approveHold(
    in userID int,
    in ISBN varchar(15),
    out copyID int,
    out dueDate varchar(100),
    out status int
)
begin
declare cid int;
declare bookCount int;
declare action varchar(20);
declare minCopyID int;
declare userType varchar(20);
declare holdLimit int;
declare loanLimit int;
declare noOfCopiesOnShelf int;

select bookCopiesUser.action into action from bookCopiesUser
where bookCopiesUser.userID = userID and bookCopiesUser.ISBN = ISBN;
select account.accountType into userType from account where account.accountID = userID;
if(userType = 'student') then
    set holdLimit = 10;
    set loanLimit = 30;
elseif(userType = 'professor') then
    set holdLimit = 20;
    set loanLimit = 60;
end if;

if(action = 'loan') then
    select bookCopiesUser.copyID into minCopyID from bookCopiesUser
    where bookCopiesUser.userID = userID and bookCopiesUser.ISBN = ISBN;
    update bookCopies set bookCopies.bookStatus = 'loan&hold', 
    bookCopies.dueDate = date_add(current_date(), interval loanLimit day)
    where bookCopies.ISBN = ISBN and bookCopies.copyID = minCopyID;
    update bookCopiesUser set bookCopiesUser.action = 'loan&hold'
    where bookCopiesUser.userID = userID and bookCopiesUser.ISBN = ISBN and bookCopiesUser.copyID = minCopyID;
    delete from holdRequest where holdRequest.userID = userID and holdRequest.ISBN = ISBN;
    set status = 1;
    set copyID = minCopyID;
    -- set dueDate = date_format(date_add(current_date(), interval loanLimit day), '%D %M %Y');
else
    select count(bookCopies.copyID) into bookCount from bookCopies
    where bookCopies.ISBN = ISBN and bookCopies.bookStatus = 'shelf';

    if(bookCount > 0) then
        select min(bookCopies.copyID) into minCopyID from bookCopies
        where bookCopies.ISBN = ISBN and bookCopies.bookStatus = 'shelf';
        update bookCopies set bookCopies.bookStatus = 'hold', bookCopies.dueDate = date_add(current_date(), interval holdLimit day)
        where bookCopies.ISBN = ISBN and bookCopies.copyID = minCopyID;
        insert into bookCopiesUser values(ISBN, minCopyID, userID, 'hold');
        delete from holdRequest where holdRequest.userID = userID and holdRequest.ISBN = ISBN;
        select count(bookCopies.copyID) into noOfCopiesOnShelf from bookCopies
        where bookCopies.bookStatus = 'shelf' and bookCopies.ISBN = ISBN;
        update book set book.noOfCopiesOnShelf = noOfCopiesOnShelf where book.ISBN = ISBN; 
        set status = 1;
        set copyID = minCopyID;
        set dueDate = date_format(date_add(current_date(), interval holdLimit day), '%D %M %Y');
    else
        set status = 0;
        set copyID = NULL;
        set dueDate = NULL;
    end if;
end if;
end //
delimiter ;

delimiter //
create procedure authenticate(
    in email varchar(70),
    in password varchar(200),
    out success int,
    out type varchar(20)
)
begin
declare pwd varchar(200);
set pwd = '';
select account.password into pwd from account
where account.email = email;
if(pwd = '') then
    set success = 0;
    set type = 'dne';
elseif(password != pwd) then
    set success = 0;
    set type = 'invalid';
else
    set success = 1;
    select account.accountType into type from account where account.email = email;
end if;
end //
delimiter ;

delimiter //
create procedure cancelHold(
	in ISBN varchar(15),
    in copyID int,
    out status int
)
begin
declare dueDate date;
declare bookStatus varchar(20);
set bookstatus = 'Hello';
set status = 0;
select bookCopies.dueDate into dueDate from bookCopies where bookCopies.ISBN = ISBN and bookCopies.copyID = copyID;
select bookCopies.bookStatus into bookStatus from bookCopies where bookCopies.ISBN = ISBN and bookCopies.copyID = copyID;
if(bookStatus = 'hold' and current_date() > dueDate) then
	delete from bookCopiesUser where bookCopiesUser.ISBN = ISBN and bookCopiesUser.copyID = copyID and bookCopiesUser.action = 'hold';
    update bookCopies set bookCopies.bookStatus = 'shelf' where bookCopies.ISBN = ISBN and bookCopies.copyID = copyID;
    update book set book.noOfCopiesOnShelf = book.noOfCopiesOnShelf + 1 where book.ISBN = ISBN; 
	set status = 1;
end if;
end //
delimiter ;

delimiter //
create procedure deleteBook(
    in ISBN varchar(15),
    out inv int
)
a: begin
declare approvedholdCount int;
declare activeHoldCount int;
declare loanCount int;
set loanCount = -1;
set approvedholdCount = -1;
set activeHoldCount = -1;
select count(userID) into approvedholdCount from bookCopiesUser
where bookCopiesUser.ISBN = ISBN and bookCopiesUser.action = 'hold';
select count(userID) into loanCount from bookCopiesUser
where bookCopiesUser.ISBN = ISBN and bookCopiesUser.action != 'hold';
select count(userID) into activeHoldCount from holdRequest
where holdRequest.ISBN = ISBN;
if(loanCount != -1) then
    set inv = 2;
    leave a;
elseif(approvedholdCount != -1) then
    set inv = 1;
    leave a;
elseif(activeHoldCount != -1) then
    set inv = 0;
    delete from holdRequest where holdRequest.ISBN = ISBN;
    delete from bookCopies where bookCopies.ISBN = ISBN;
    delete from book where book.ISBN = ISBN; -- Other info is deleted due to on delete cascade
else 
	delete from bookCopies where bookCopies.ISBN = ISBN;
    delete from book where book.ISBN = ISBN; -- Other info is deleted due to on delete cascade
end if;
end //
delimiter ;

delimiter //
create procedure detailsOfBook(
	in userID int,
    in ISBN varchar(15)
)
begin
declare title1 varchar(100);
declare yearOfPublication1 int;
declare totalCopies1 int;
declare noOfCopiesOnShelf1 int;
declare authors1 varchar(200);
declare category1 varchar(20);
declare image1 varchar(1000);
declare fav1 int;
declare userRating1 int;
declare holdStatus1 int;
declare avgRating1 float;
declare x1 varchar(3);
declare y1 varchar(20);
declare y2 int;
set y1 = 'NUll';
set x1 = 'YE';
set y2 = -10;
select book.title into title1 from book where book.ISBN = ISBN;
select book.yearOfPublication into yearOfPublication1 from book where book.ISBN = ISBN;
select book.totalCopies into totalCopies1 from book where book.ISBN = ISBN;
select book.noOfCopiesOnShelf into noOfCopiesOnShelf1 from book where book.ISBN = ISBN;
select book.authors into authors1 from book where book.ISBN = ISBN;
select book.category into category1 from book where book.ISBN = ISBN;
select book.image into image1 from book where book.ISBN = ISBN;
select readingList.favourite into x1 from readingList where readingList.userID = userID and readingList.ISBN = ISBN;
if(x1 = 'YES') then
	set fav1 = 1;
else
	set fav1 = 0;
end if;
select rating.rating into userRating1 from rating where rating.userID = userID and rating.ISBN = ISBN;
select bookCopiesUser.action into y1 from bookCopiesUser where bookCopiesUser.userID = userID and bookCopiesUser.ISBN = ISBN;
select holdRequest.requestID into y2 from holdRequest where holdRequest.userID = userID and holdRequest.ISBN = ISBN;
if(y1 = 'hold' or y1 = 'loan&hold') then
	set holdStatus1 = 0;
else 
	set holdStatus1 = 1;
end if;
if(y2 = -10 and holdStatus1 = 1) then
	set holdStatus1 = 1;
else
	set holdStatus1 = 0;
end if;
select avg(rating.rating) into avgRating1 from rating where rating.ISBN = ISBN;
create table temp4(
title varchar(100),
yearOfPublication int,
totalCopies int,
noOfCopiesOnShelf int,
authors varchar(200),
category varchar(20),
image varchar(1000),
fav int,
rating int,
holdStatus int,
avgRating float,
primary key(title)
);
insert into temp4 values(title1, yearOfPublication1, totalCopies1, noOfCopiesOnShelf1, authors1, category1, image1, fav1, userRating1, holdStatus1, avgRating1);
select * from temp4;
drop table temp4;
end //
delimiter ;

delimiter //
create procedure detailsOfBookWithoutUser(
    in ISBN varchar(15)
)
begin
declare title1 varchar(100);
declare yearOfPublication1 int;
declare totalCopies1 int;
declare noOfCopiesOnShelf1 int;
declare authors1 varchar(200);
declare category1 varchar(20);
declare image1 varchar(1000);
declare avgRating1 float;
select book.title into title1 from book where book.ISBN = ISBN;
select book.yearOfPublication into yearOfPublication1 from book where book.ISBN = ISBN;
select book.totalCopies into totalCopies1 from book where book.ISBN = ISBN;
select book.noOfCopiesOnShelf into noOfCopiesOnShelf1 from book where book.ISBN = ISBN;
select book.authors into authors1 from book where book.ISBN = ISBN;
select book.category into category1 from book where book.ISBN = ISBN;
select book.image into image1 from book where book.ISBN = ISBN;
select avg(rating.rating) into avgRating1 from rating where rating.ISBN = ISBN;
create table temp4(
title varchar(100),
yearOfPublication int,
totalCopies int,
noOfCopiesOnShelf int,
authors varchar(200),
category varchar(20),
image varchar(1000),
avgRating float
);
insert into temp4 values(title1, yearOfPublication1, totalCopies1, noOfCopiesOnShelf1, authors1, category1, image1, avgRating1);
select * from temp4;
drop table temp4;
end //
delimiter ;

delimiter //
create procedure detailsOfUser(
    in userID int,
    out name varchar(50),
    out email varchar(70),
    out address varchar(500),
    out unpaidFines int
)
begin
select user.name into name
from user where user.userID = userID;
select user.email into email
from user where user.userID = userID;
select user.address into address
from user where user.userID = userID;
select user.unpaidFines into unpaidFines
from user where user.userID = userID;
end //
delimiter ;

delimiter //
create procedure emailDetails(
	in userID int,
    out unpaidFine int
)
begin
select user.unpaidFines into unpaidFine from user where user.userID = userID;
select book.ISBN, book.title, bookCopies.copyID, bookCopiesUser.action, bookCopies.dueDate
from book inner join bookCopies inner join bookCopiesUser
on book.ISBN = bookCopies.ISBN and bookCopies.ISBN = bookCopiesUser.ISBN and bookCopies.copyID = bookCopiesUser.copyID
where bookCopiesUser.userID = userID and bookCopies.dueDate < current_date(); 
end //
delimiter ;

delimiter //
create procedure issueBook(
    in userID int,
    in ISBN varchar(15),
    in copyID int,
    out success int,
    out dueDate date
)
a: begin
declare borrowed int;
declare userType varchar(20);
declare bookAction varchar(20);
declare loanLimit int;
declare unpaidFine int;
select count(bookCopiesUser.ISBN) into borrowed from bookCopiesUser
where bookCopiesUser.userID = userID and bookCopiesUser.action != 'hold';
select user.unpaidFines into unpaidFine from user where user.userID = userID;
select account.accountType into userType from account where account.accountID = userID;
if(userType = 'student' and borrowed > 2) then
    set success = 0;
    set dueDate = NULL;
    leave a;
elseif(userType = 'professor' and borrowed > 4) then
    set success = 0;
    set dueDate = NULL;
    leave a;
elseif(unpaidFine > 1000) then
    set success = 0;
    set dueDate = NULL;
    leave a;
end if;
if(userType = 'student') then
    set loanLimit = 30;
elseif(userType = 'professor') then
    set loanLimit = 60;
end if;
select bookCopiesUser.action into bookAction from bookCopiesUser
where bookCopiesUser.userID = userID and bookCopiesUser.ISBN = ISBN and bookCopiesUser.copyID = copyID;
if(bookAction = 'loan&hold') then
	call returnBook(userID, ISBN, copyID);
    update book set book.noOfCopiesOnShelf = book.noOfCopiesOnShelf - 1
    where book.ISBN = ISBN;
    update bookCopies set bookCopies.bookStatus = 'loan', bookCopies.dueDate = date_add(current_date(), interval loanLimit day)
    where bookCopies.ISBN = ISBN and bookCopies.copyID = copyID;
    insert into bookCopiesUser values(ISBN, copyID, userID, 'loan');
    set success = 1;
    set dueDate = date_add(current_date(), interval loanLimit day);
elseif(bookAction = 'hold') then
    update bookCopies set bookCopies.bookStatus = 'loan', bookCopies.dueDate = date_add(current_date(), interval loanLimit day)
    where bookCopies.ISBN = ISBN and bookCopies.copyID = copyID;
    update bookCopiesUser set bookCopiesUser.action = 'loan' where bookCopiesUser.userID = userID and
    bookCopiesUser.ISBN = ISBN and bookCopiesUser.copyID = copyID;
    set success = 1;
    set dueDate = date_add(current_date(), interval loanLimit day);
elseif(bookAction = 'loan') then
    set success = 0;
    set dueDate = NULL;
else 
    update book set book.noOfCopiesOnShelf = book.noOfCopiesOnShelf - 1
    where book.ISBN = ISBN;
    update bookCopies set bookCopies.bookStatus = 'loan', bookCopies.dueDate = date_add(current_date(), interval loanLimit day)
    where bookCopies.ISBN = ISBN and bookCopies.copyID = copyID;
    insert into bookCopiesUser values(ISBN, copyID, userID, 'loan');
    set success = 1;
    set dueDate = date_add(current_date(), interval loanLimit day);
end if; 
end //
delimiter ;

delimiter //
create procedure listOfActiveHoldRequests(
    in userID int
)
begin
create table temp
select holdRequest.ISBN from holdRequest where holdRequest.userID = userID;
select temp.ISBN, book.title, book.yearOfPublication, book.authors, book.category, book.image
from temp inner join book
on temp.ISBN = book.ISBN;
drop table temp;
end //
delimiter ;

delimiter //
create procedure listOfApprovedHoldRequests(
    in userID int
)
begin
create table temp
select bookCopiesUser.ISBN, bookCopiesUser.copyID, bookCopies.dueDate 
from bookCopiesUser inner join bookCopies 
on bookCopies.ISBN = bookCopiesUser.ISBN and bookCopies.copyID = bookCopiesUser.copyID
where bookCopiesUser.userID = userID
and bookCopiesUser.action != 'loan';
select temp.ISBN, temp.copyID, temp.dueDate, book.title, book.yearOfPublication, book.authors, book.category, book.image
from book inner join temp
on book.ISBN = temp.ISBN;
drop table temp;

end //
delimiter ;

delimiter //
create procedure listOfBooksOnLoan(
    in userID int
)
begin
create table temp
select bookCopiesUser.ISBN, bookCopiesUser.copyID, bookCopies.dueDate
from bookCopiesUser inner join bookCopies 
on bookCopies.ISBN = bookCopiesUser.ISBN and bookCopies.copyID = bookCopiesUser.copyID
where bookCopiesUser.userID = userID
and bookCopiesUser.action != 'hold';
select temp.ISBN, temp.copyID, temp.dueDate, book.title, book.yearOfPublication, book.authors, book.category, book.image 
from temp inner join book
on book.ISBN = temp.ISBN;
drop table temp;
end //
delimiter ;

delimiter //
create procedure listOfFavouriteBooks(
    in userID int
)
begin
create table temp
select readingList.ISBN, readingList.userID from readingList where readingList.userID = userID and readingList.favourite = 'YES';
select temp.ISBN, user.name, user.userID, book.title, book.yearOfPublication, book.authors, book.category, book.image 
from temp inner join book inner join user
on book.ISBN = temp.ISBN and temp.userID = user.userID;
drop table temp;
end //
delimiter ;

delimiter //
create procedure listOfFriendsOfUser(
    in userID int
)
begin
select friendUser.friendID from friendUser where friendUser.userID = userID;
end //
delimiter ;

delimiter //
create procedure listOfReadBooks(
    in userID int
)
begin
create table temp
select readingList.ISBN, readingList.userID from readingList
where readingList.userID = userID and readingList.status = 'read';
select temp.ISBN, user.name, user.userID, book.title, book.yearOfPublication, book.authors, book.category, book.image
from temp inner join book inner join user
on temp.ISBN = book.ISBN and user.userID = temp.userID;
drop table temp;
end //
delimiter ;

delimiter //
create procedure markAsFavourite(
    in userID int,
    in ISBN varchar(15),
    in readBook int
)
begin
declare fav varchar(3);
set fav = '';
select readingList.favourite into fav from readingList where readingList.userID = userID and readingList.ISBN = ISBN;
if(fav != '') then
	if(readBook = 1) then
	update readingList set readingList.favourite = 'YES' where readingList.userID = userID and readingList.ISBN = ISBN;
	update readingList set readingList.status = 'read' where readingList.userID = userID and readingList.ISBN = ISBN;
	else
	update readingList set readingList.favourite = 'YES' where readingList.userID = userID and readingList.ISBN = ISBN;
	update readingList set readingList.status = 'unread' where readingList.userID = userID and readingList.ISBN = ISBN;
	end if;
else
	if(readBook = 1) then
		insert into readingList values(ISBN, userID, 'read', 'YES');
	else
		insert into readingList values(ISBN, userID, 'unread', 'YES');
	end if;
end if;
end //
delimiter ;

delimiter //
create procedure rateBookWithoutUser(
    in ISBN varchar(15),
    in rating int
)
begin
insert into rating(ISBN, userID, rating) values(ISBN, NULL, rating);
end //
delimiter ;

delimiter //
create procedure rateBookWithUser(
    in userID int,
    in ISBN varchar(15),
    in rating int
)
begin
declare ID int;
set ID = -1;
select rating.userID into ID from rating where rating.userID = userID and rating.ISBN = ISBN;
if(ID = -1) then
insert into rating(ISBN, userID, rating) values(ISBN, userID, rating);
else
update rating set rating.rating = rating where rating.userID = userID and rating.ISBN = ISBN;
end if;
end //
delimiter ;

delimiter //
create procedure removeFromFavourite(
    in userID int,
    in ISBN varchar(15)
)
begin
update readingList set readingList.favourite = 'NO' 
where readingList.userID = userID and readingList.ISBN = ISBN;
end //
delimiter ;

delimiter //
create procedure requestHold(
    in userID int,
    in ISBN varchar(15),
    out status int
)
begin
-- Declare Variables
declare cid int;
declare size1 int;
declare size2 int;
declare holdLimit1 int;
declare holdLimit2 int;
declare unpaidFine int;
declare userType varchar(20);

-- Check if user is trying for loan and hold
select bookCopiesUser.copyID into cid from bookCopiesUser
where bookCopiesUser.userID = userID and bookCopiesUser.ISBN = ISBN;
if(cid = NULL) then
    -- User doesn't have book on loan/hold/loan&hold
    insert into holdRequest values(ISBN, userID, current_timestamp);
    set status = 1;
else 
    -- temp1 is list of other users who put a hold on same book
    create table temp1
    select holdRequest.userID from holdRequest
    where holdRequest.ISBN = ISBN;
    select count(temp1.userID) into size1 from temp1;
    -- temp2 is list of users in temp1 who are trying for loan and hold
    create table temp2
    select bookCopiesUser.userID from bookCopiesUser
    where bookCopiesUser.ISBN = ISBN and 
    bookCopiesUser.action = 'loan' and
    bookCopiesUser.userID in
    (select temp1.userID from temp1);
    select count(temp2.userID) into size2 from temp2;
    if(size1 = size2) then
        -- All users are trying for loan and hold
        -- Fetch user type, unpaid fines and total books put under hold by the user
        select user.unpaidFines into unpaidFine from user where user.userID = userID;
        select account.accountType into userType from account where account.accountID = userID;
        select count(bookCopiesUser.ISBN) into holdLimit1 from bookCopiesUser
        where bookCopiesUser.userID = userID;
        select count(holdRequest.ISBN) into holdLimit2 from holdRequest
        where holdRequest.userID = userID;
        if(userType = 'student' and (holdLimit1 + holdLimit2) > 4) then
            -- hold limit (approved and active) is 3 for students
            set status = 3;
        elseif(userType = 'professor' and (holdLimit1 + holdLimit2) > 6) then
            -- hold limit (approved and active) is 5 for professors
            set status = 3;
        elseif(unpaidFine > 1000) then
            -- books can't be issued or hold if unpaid fine > 1000
            set status = 4;
        else
            -- All conditions satisfied to request hold
            insert into holdRequest(ISBN, userID, holdTime) values(ISBN, userID, current_timestamp());
            set status = 1;
        end if;
    else
        -- Atleast one user doesn't have the book and has put hold
        set status = 2;
    end if;
    drop table temp2;
    drop table temp1;
end if;
end //
delimiter ;

delimiter //
create procedure returnBook(
    in userID int,
    in ISBN varchar(15),
    in copyID int
)
begin
declare status varchar(20);
set status = '';
delete from bookCopiesUser where bookCopiesUser.userID = userID and 
bookCopiesUser.ISBN = ISBN and bookCopiesUser.copyID = copyID;
update bookCopies set bookCopies.bookStatus = 'shelf', bookCopies.dueDate = NULL
where bookCopies.ISBN = ISBN and bookCopies.copyID = copyID;
update book set book.noOfCopiesOnShelf = book.noOfCopiesOnShelf + 1
where book.ISBN = ISBN;
select readingList.status into status from readingList where readingList.userID = userID and readingList.ISBN = ISBN;
if(status = '') then
	insert into readingList values(ISBN, userID, 'read', 'NO');
else
	update readingList set readingList.status = 'read' where readingList.ISBN = ISBN and readingList.userID = userID;
end if;
end //
delimiter ;

delimiter //
create procedure reviewBook(
    in userID int,
    in ISBN varchar(15),
    in reviewText varchar(500)
)
begin
declare review varchar(500);
set review = '';
select review.reviewText into review from review where review.userID = userID and review.ISBN = ISBN;
if(review = '') then 
insert into review(reviewText, userID, ISBN) values(reviewText, userID, ISBN);
else
update review set review.reviewText = reviewText where review.userID = userID and review.ISBN = ISBN;
end if;
end //
delimiter ;

delimiter //
create procedure reviewsOfBook(
	in ISBN varchar(15)
)
begin
select user.userID, user.name, review.reviewText
from user inner join review
on user.userID = review.userID
where review.ISBN = ISBN;
end //
delimiter ;

delimiter //
create procedure sendFriendRequest(
    in requesterID int,
    in requestedID int
)
begin
insert into friendRequest values(requesterID, requestedID);
end //
delimiter ;

delimiter //
create procedure shelfCapacity(
	in shelfID int
)
begin
declare presentShelf int;
declare totalCapacity int;
select shelf.capacity into totalCapacity from shelf where shelf.shelfID = shelfID;
select count(bookCopies.ISBN) into presentShelf from bookCopies where bookCopies.shelfID = shelfID;
select (totalCapacity - presentShelf); 
end //
delimiter ;

delimiter //
create procedure signUpGoogle(
    in email varchar(70),
    in name varchar(50),
    in type varchar(20),
    in address varchar(500),
    out did int
)
begin
declare userID int;
declare exit handler for 1062
begin
set did = 1;
end;
insert into account(password, accountType, email) values(NULL, type, email);
select account.accountID into userID from account where account.email = email;
insert into user values(userID, name, email, address, 0);
end //
delimiter ;

delimiter //
create procedure signUpUser(
    in email varchar(70),
    in password varchar(200),
    in name varchar(50),
    in address varchar(500),
    in type varchar(20),
    out did int
)
begin
declare userID int;
declare exit handler for 1062
begin
set did = 1;
end;
insert into account(password, accountType, email) values(password, type, email);
select account.accountID into userID from account where account.email = email;
insert into user values(userID, name, email, address, 0);
end //
delimiter ;

delimiter //
create procedure unfriend(
    in userID int,
    in friendID int
)
begin
delete from friendUser where friendUser.userID = userID and friendUser.friendID = friendID;
delete from friendUser where friendUser.userID = friendID and friendUser.friendID = userID;
end //
delimiter ;

delimiter //
create procedure updateBook(
    in ISBN varchar(15),
    in title varchar(100),
    in yearOfPublication int,
    in authors varchar(200),
    in category varchar(20),
    in image varchar(1000),
    in noOfCopies int,
    in shelfID int,
    out inv int
)
b: begin
declare presentNo int;
declare presentShelf int;
declare updateShelf int;
declare shelfCapacity int;
declare x int;
declare y int;
declare z varchar(20);
declare maxCopyID int;
select book.totalCopies into presentNo from book where book.ISBN = ISBN;
if(noOfCopies >= presentNo) then
    set updateShelf = noOfCopies - presentNo;
    select book.noOfCopiesOnShelf into presentShelf from book
    where book.ISBN = ISBN;
    select shelf.capacity into shelfCapacity from shelf where shelf.shelfID = shelfID;
    if(updateShelf > shelfCapacity - presentShelf) then
        set inv = 2;
        leave b;
    end if; 
    update book set book.title = title, book.yearOfPublication = yearOfPublication,
    book.authors = authors, book.totalCopies = noOfCopies,
    book.category = category, book.image = image,
    book.noOfCopiesOnShelf = book.noOfCopiesOnShelf + updateShelf
    where book.ISBN = ISBN;
    set x = presentNo + 1;
    a:loop
        if(x > updateShelf + presentNo) then
            leave a;
        end if;
        insert into bookCopies values(ISBN, x, 'shelf', NULL, shelfID);
        set x = x + 1;
    end loop;
else
    select book.noOfCopiesOnShelf into presentShelf from book 
    where book.ISBN = ISBN;
    if(presentShelf >= presentNo - noOfCopies) then
        update book set book.title = title, book.yearOfPublication = yearOfPublication,
        book.authors = authors, book.totalCopies = noOfCopies,
        book.category = category, book.image = image,
        book.noOfCopiesOnShelf = book.noOfCopiesOnShelf - presentNo + noOfCopies
        where book.ISBN = ISBN;
        select max(bookCopies.copyID) into maxCopyID from bookCopies
        where bookCopies.ISBN = ISBN and bookCopies.bookStatus = 'shelf';
        set y = 1;
        c: loop
            if(y > presentNo - noOfCopies) then
                leave c;
            end if;
            select bookCopies.bookStatus into z from bookCopies where bookCopies.ISBN = ISBN and bookCopies.copyID = maxCopyID;
            if(z = 'shelf') then 
                delete from bookCopies where bookCopies.ISBN = ISBN and bookCopies.copyID = maxCopyID and bookCopies.bookStatus = 'shelf';
                set y = y + 1;
            end if;    
            set maxCopyID = maxCopyID - 1;
        end loop;
    else
        set inv = 1;
    end if;    
end if;
end //
delimiter ;

delimiter //
create procedure updateFine(
    in userID int
)
begin
declare noOfDelayedReturns int;
declare totalFine int;
create table temp
select bookCopiesUser.userID, bookCopiesUser.ISBN, bookCopiesUser.copyID, bookCopies.dueDate
from bookCopies inner join bookCopiesUser on
bookCopies.ISBN = bookCopiesUser.ISBN and bookCopies.copyID = bookCopiesUser.copyID
where bookCopiesUser.userID = userID and bookCopiesUser.action != 'hold' and bookCopies.dueDate > current_date();
update temp set temp.userID = datediff(current_date(), dueDate);
select sum(temp.userID) into totalFine from temp;
set totalFine = totalFine * 2;
if(totalFine != NULL) then
update user set user.unpaidFines = totalFine where user.userID = userID;
end if;
drop table temp;
end //
delimiter ;