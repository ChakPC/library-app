-- delete book (by librarian)
-- procedure definition
delimiter //
create procedure deleteBook(
    in ISBN varchar(15),
    out inv int
)
a: begin
declare approvedholdCount int;
declare activeHoldCount int;
declare loanCount int;
select count(bookCopiesUser.userID) into approvedholdCount from bookCopiesUser
where bookCopiesUser.ISBN = ISBN and bookCopiesUser.action = 'hold';
select count(bookCopiesUser.userID) into loanCount from bookCopiesUser
where bookCopiesUser.ISBN = ISBN and bookCopiesUser.action != 'hold';
select count(holdRequest.userID) into activeHoldCount from holdRequest
where holdRequest.ISBN = ISBN;
if(loanCount != null) then
    set inv = 2;
    leave a;
elseif(approvedholdCount != null) then
    set inv = 1;
    leave a;
elseif(activeHoldCount != null) then
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

-- call procedure
call deleteBook('123', @inv);
select @inv;
select @loanCount;
-- inv = 0: Only active hold requests exist
-- inv = 1: active and approved hold exist
-- inv = 2: Loan, Hold, Loan&Hold exist

-- drop procedure deleteBook;