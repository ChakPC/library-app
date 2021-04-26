-- Return a book to library by user
-- procedure definition
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
delete from holdRequest where holdRequest.userID = userID and holdRequest.ISBN = ISBN;
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

-- call procedure
call returnBook(4, '123', 1);

-- drop procedure returnBook;