-- Request to put hold on a boook by a user
-- procedure definition
delimiter //
create procedure requestHold(
    in userID int,
    in ISBN varchar(15),
    out status int
)
x:begin
-- Declare Variables
declare cid int;
declare size1 int;
declare size2 int;
declare holdLimit1 int;
declare holdLimit2 int;
declare unpaidFine int;
declare userType varchar(20);
set cid = 0;
-- Check if user is trying for loan and hold
select bookCopiesUser.copyID into cid from bookCopiesUser
where bookCopiesUser.userID = userID and bookCopiesUser.ISBN = ISBN;
if(cid = 0) then
    -- User doesn't have book on loan/hold/loan&hold
    insert into holdRequest(ISBN, userID, holdTime) values(ISBN, userID, current_timestamp);
    set status = 1;
    leave x;
else 
    -- temp1 is list of other users who put a hold on same book
    set size1 = -1;
    create table temp1
    select holdRequest.userID from holdRequest
    where holdRequest.ISBN = ISBN;
    select count(temp1.userID) into size1 from temp1;
    if(size1 = 0) then
		insert into holdRequest(ISBN, userID, holdTime) values(ISBN, userID, current_timestamp);
		set status = 1;
        drop table temp1;
        leave x;
    end if;
    -- temp2 is list of users in temp1 who are trying for loan and hold
    set size2 = -1;
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
        set unpaidFine = 0;
        set holdLimit1 = 0;
        set holdLimit2 = 0;
        select user.unpaidFines into unpaidFine from user where user.userID = userID;
        select account.accountType into userType from account where account.accountID = userID;
        select count(bookCopiesUser.ISBN) into holdLimit1 from bookCopiesUser
        where bookCopiesUser.userID = userID;
        select count(holdRequest.ISBN) into holdLimit2 from holdRequest
        where holdRequest.userID = userID;
        if(userType = 'student' and (holdLimit1 + holdLimit2) > 4) then
            -- hold limit (approved and active) is 5 for students
            set status = 3;
            drop table temp2;
			drop table temp1;
            leave x;
        elseif(userType = 'professor' and (holdLimit1 + holdLimit2) > 6) then
            -- hold limit (approved and active) is 7 for professors
            set status = 3;
			drop table temp2;
			drop table temp1;
            leave x;
        elseif(unpaidFine > 1000) then
            -- books can't be issued or hold if unpaid fine > 1000
            drop table temp2;
			drop table temp1;
            set status = 4;
            leave x;
        else
            -- All conditions satisfied to request hold
            insert into holdRequest(ISBN, userID, holdTime) values(ISBN, userID, current_timestamp());
            set status = 1;
            drop table temp2;
			drop table temp1;
            leave x;
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

-- call procedure
call requestHold(2, '100', @status);
select @status;
-- status = 1 : Hold request placed
-- status = 2 : Hold already placed by someone else
-- status = 3 : Hold limit crossed
-- status = 4 : Unpaid Fines limit crossed

-- drop procedure requestHold;

select * from holdrequest;


