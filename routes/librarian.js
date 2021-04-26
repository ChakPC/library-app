const { createConnection } = require('mysql');

const router = require('express').Router();
const path = '../views/librarian/';
const domain = require('./domain')
const href = domain.href;

const cquery = async (sql) => {
    return new Promise((resolve, reject) => {
        connection.query(sql, (err, result) => {
            if (err) throw err;
            resolve(result);
        })
    }
    )
}

router.get('/home', async (req, res) => {
    let temp = await cquery(`select * from librarian where librarian.librarianID = ${req.user.accountID};`);
    console.log(temp);
    let message = req.query.msg;
    let form = req.query.form;
    res.render(path + 'librarian_home.ejs', { path: href, name: temp[0].name, address: temp[0].address, id: temp[0].librarianID, message: message, form: form });
})

router.post('/addbook', async (req, res) => {
    let data = req.body.data;
    let obj = (Object.fromEntries([...new URLSearchParams(data)]));
    await cquery(`call addBook('${obj.isbn}', '${obj.title}', ${obj.year}, ${obj.copies}, '${obj.authors}', '${obj.category}', '${obj.image}', ${obj.shelfid}, @did, @inv);`);
    let did = await cquery(`select @did;`);
    let inv = await cquery(`select @inv;`);
    console.log(did);
    console.log(inv);
    let error="",message="";
    if (did[0]['@did'] == 1) {
        error = 'Duplicate ISBN found. Unable to add book to database';
    }
    else if (inv[0]['@inv'] == 1) {
        error = 'Shelf Capacity is insufficient...Please select a different shelf';
    }
    else {
        message='Book Added Successfully';
    }
    res.send({
        message,error
    })
})

router.post('/deletebook', async (req, res) => {
    let data = req.body.data;
    let obj = (Object.fromEntries([...new URLSearchParams(data)]));
    console.log(obj);
    await cquery(`call deleteBook('${obj.isbn}', @inv);`);
    let message = "";
    let error = "";
    let inv = await cquery(`select @inv;`);
    if (inv[0]['@inv'] == 0) {
        error = 'Active Hold Requests Exist';
    }
    else if (inv[0]['@inv'] == 1) {
        error = 'Unable to Delete. Some approved holds exist';
    }
    else if (inv[0]['@inv'] == 2) {
        error = 'Unable to Delete. Some copies on loan.';
    }
    else {
        message = 'Book Deleted Succesfully';
    }
    res.send({
        message,error
    })
})

router.post('/updatebook', async (req, res) => {
    let data = req.body.data;
    obj = (Object.fromEntries([...new URLSearchParams(data)]));
    console.log(obj);
    await cquery(`call updateBook('${obj.isbn}', '${obj.title}', ${obj.year}, '${obj.author}', '${obj.category}', '${obj.image}', ${obj.copies}, ${obj.shelf}, @inv);`);
    let inv = await cquery(`select @inv;`);
    let message="",error="";
    if (inv[0]['@inv'] == 1) {
        error= 'Unable to Update. Please check number of copies';
    }
    else if (inv[0]['@inv'] == 2) {
        error = 'Unable to Update. Shelf Capacity is less.';
    }
    else {
        message = 'Book Updated Succesfully';
    }
    res.send({message, error});
})

router.post('/issuebook', async (req, res) => {
    let data = req.body.data;
    let obj = (Object.fromEntries([...new URLSearchParams(data)]));
    console.log(obj);
    let userID = await cquery(`select user.userID from user where user.email = '${obj.email}';`);
    let message = "",error="";
    if (userID.length == 0) {
        error= 'No users with given email found';
    } else {
        await cquery(`call issueBook(${userID[0]['userID']}, '${obj.isbn}', ${obj.copyid}, @success, @dueDate);`);
        let success = await cquery(`select @success;`);
        if (success[0]['@success'] == 1) {
            let dueDate = await cquery(`select @dueDate;`);
            message = `Book issued succesfully and due date is ${dueDate[0]['@dueDate']}`;
        }
        else {
            error = 'Book can not be issued due to borrow limit or fine limit';
        }
    }
    res.send({ message,error });
})

router.post('/withdrawbook', async (req, res) => {
    let data = req.body.data;
    let obj = (Object.fromEntries([...new URLSearchParams(data)]));
    console.log(obj);
    let userID = await cquery(`select user.userID from user where user.email = '${obj.email}';`);
    let message="";
    let error="";
    if (userID.length == 0) {
        error = 'No users with given email found';
    } else {
        await cquery(`call returnBook(${userID[0]['userID']}, '${obj.isbn}', ${obj.copyid});`);
        message = `Book Returned to shelf succesfully`;
    }
    res.send({ message,error });
})

router.post('/fine', async (req, res) => {
    let data = req.body.data;
    data = (Object.fromEntries([...new URLSearchParams(data)]));
    await cquery(`update user set user.unpaidFines = 0 where user.email = '${data.email}';`);
    let message = `Dues cleared!`;
    res.send({ message });
})

router.post('/viewfine', async (req, res) => {
    let email = req.body.email;
    let unpaidFines = await cquery(`select unpaidFines from user where email = '${email}';`);
    console.log(unpaidFines);
    let message = "",error="";
    if(unpaidFines.length){
        message = `The unpaid fines are ${unpaidFines[0].unpaidFines}`;
    }else{
        error = 'No user found.'
    }
    res.send({message,error});
})



module.exports = router;