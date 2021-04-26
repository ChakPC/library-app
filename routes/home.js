const router = require('express').Router();
const path = '../views/home/';
const mysql = require('mysql');
const domain = require('./domain')
const href = domain.href;

const cquery = async  (sql,req,res)=>{
    return new Promise((resolve,reject)=>{
        connection.query(sql,(err,result)=>{
            if(err) throw err;
            resolve(result);
        })
    }
    )
}

let books = [];


router.get('/',(req,res)=>{
    res.render(path+'home_page.ejs',{path : href});
})

router.get('/books',(req,res)=>{
    res.render(path+'books_without_login.ejs',{path : href});
})

router.post('/displayinfo',(req,res)=>{
    connection.query('select * from person;',(err,result) => {
        if(err) throw err;
        console.log(result);
        res.send(result);
    })
})

router.post('/getbooksdata',async (req,res)=>{
    let c = req.body.criteria;
    let sub=req.body.sub;
    if(books.length == 0){
        console.log('called');
        books = await cquery('select * from book;');
    }
    if(sub.length == 0){
        res.send({});
    }else{
        let result = [];
        for(let i=0;i<books.length;i++){
            let temp1 = await cquery(`call detailsOfBookWithoutUser(${books[i].ISBN})`);
            console.log(temp1);
            let str="";
            if(c== "Search by Name"){
                str = ""+books[i].title.toUpperCase();
            }else{
                str = ""+books[i].authors.toUpperCase();
            }
            // console.log(temp1[1]);
            if(str.indexOf(sub.toUpperCase()) > -1){
                // temp1[0][0].avgRat = temp1[0][0]["avg(rating.rating)"];
                temp1[0][0].ISBN = books[i].ISBN;
                let temp2 = await cquery(`call reviewsOfBook(${books[i].ISBN});`);
                let temp3 = await cquery(`select count(bookCopiesUser.userID) as count from bookCopiesUser where bookCopiesUser.ISBN = ${books[i].ISBN} and bookCopiesUser.action = 'hold';`);
                
                temp1[0][0].numholds = temp3[0].count;
                temp1[0][0].reviews = temp2[0];
                // console.log(temp1[1]);
                result.push(temp1[0][0]);
            }
        }
        res.send(result);
    }

})

router.post('/rate',async(req,res)=>{
    let isbn =req.body.isbn;
    let rating = req.body.rating;
    console.log(isbn,rating);
    await cquery(`call rateBookWithoutUser(${isbn},${rating})`);
})

router.get('/aboutus',(req,res)=>{
    res.render(path+'about_us.ejs',{path : href,user: ""});
})

router.get('/contactus',(req,res)=>{
    res.render(path+'contact_us.ejs',{path : href,user: ""});
})

router.post('/feedback',async (req,res)=>{
    let data = req.body.data;
    let obj = (Object.fromEntries([...new URLSearchParams(data)]));
    console.log(obj);
    await cquery(`insert into feedback(name,email,phone,feedback) values ('${obj.name}','${obj.email}','${obj.phone}','${obj.feedback}');`);
    res.send({
        message : 'Thank you for your feedback!!'
    })
})
module.exports = router;