const router = require('express').Router();
const path = '../views/user/';
const domain = require('./domain')
const href = domain.href;


const cquery = async  (sql,req,res)=>{
    return new Promise((resolve,reject)=>{
        connection.query(sql,(err,result)=>{
            if(err) console.log(err);
            else resolve(result);
        })
    }
    )
}

let books = [];
let users = [];
router.get('/books',async(req,res)=>{
    let search = req.query.search;
    res.render(path+'books.ejs',{path : href,search});
})

router.get('/home',async (req,res)=>{
    let userid=req.user.accountID;
    let temp = await cquery(`select name,address from user where userID=${userid};`);
    let loanbook = await cquery(`call listOfBooksOnLoan(${userid});`);
    let booksread = await cquery(`select * from book where ISBN in (select ISBN from readingList where userID = ${userid} and status = 'read');`);
    let favourite =  await cquery(`call listOfFavouriteBooks(${userid});`);
    let activeholds = await cquery(`call listOfActiveHoldRequests(${userid});`);
    let apprholds = await cquery(`call listOfApprovedHoldRequests(${userid});`);
    let freq = await cquery(`select * from user where userID in (select requesterID from friendRequest where requestedID = ${userid});`);
    let freadlist = [];
    let friends = await cquery(`select friendID from friendUser where userID = ${req.user.accountID};`);
    let len=0;
    for(let j =0;j<friends.length;j++){
        let favbooks = await cquery(`call listOfFavouriteBooks(${friends[j].friendID});`);
        let freadbooks = await cquery(`call listOfReadBooks(${friends[j].friendID});`);
        let pile = [...favbooks[0],...freadbooks[0]];
        let data = Array.from(new Set(pile.map(JSON.stringify))).map(JSON.parse);
        freadlist.push(data);
        len+=data.length;
    }
    console.log(freadlist);
    console.log(freq);
    let name = temp[0].name;
    let address = temp[0].address;
    console.log(temp);
    res.render(path+'user_home.ejs',{path : href,name,address,userid,loanbook,booksread,favourite,activeholds,freq,apprholds,freadlist,len});
});

router.get('/temp',(req,res)=>{
    res.render(path+'temp',{path : href});
})


router.post('/getbooksdata',async (req,res)=>{
    let c = req.body.criteria;
    let sub=req.body.sub;
    if(books.length == 0){
        console.log('called');
    }
    books = await cquery('select * from book;');
    if(sub.length == 0){
        res.send({});
    }else{
        let result = [];
        for(let i=0;i<books.length;i++){
            let temp1 = await cquery(`call detailsOfBook(${req.user.accountID},${books[i].ISBN})`);
            // console.log(temp1);
            let str="";
            if(c== "Search by Name"){
                str = ""+books[i].title.toUpperCase();
            }else{
                str = ""+books[i].authors.toUpperCase();
            }
            console.log(books[i].title);
            // console.log(books[i].ISBN,str.indexOf(sub));
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
        // console.log(result)
        res.send(result);
    }

})

router.post('/markfav', async(req,res)=>{
    let isbn = req.body.isbn;
    let read = req.body.read;
    if(read == 'yes'){
        read=1;
    }else{
        read=0;
    }
    await cquery(`call markAsFavourite(${req.user.accountID},${isbn},${read});`);
    res.send({
        message: 'successs'
    })
})

router.post('/unmarkfav',async(req,res)=>{
    let isbn=req.body.isbn;
    await cquery(`call removeFromFavourite(${req.user.accountID},${isbn});`);
    res.send({
        message: 'success'
    })
})

router.post('/rate',async(req,res)=>{
    let isbn =req.body.isbn;
    let rating = req.body.rating;
    console.log(isbn,rating);
    await cquery(`call rateBookWithUser(${req.user.accountID},${isbn},${rating})`);
})

router.post('/requesthold',async(req,res)=>{
    let isbn = req.body.isbn;
    console.log(isbn);
    await cquery(`call requestHold(${req.user.accountID},${isbn},@status);`);
    let status = await cquery(`select @status;`);
    res.send(status[0]);
    console.log(status);
})

router.get('/friends',async (req,res)=>{
    res.render(path + 'friends.ejs', {path : href});
})

router.post('/findfriends',async (req,res)=>{
    let sub = req.body.sub; 
    if(users.length == 0){
    }
    users = await cquery(`select * from user where userId <> ${req.user.accountID};`);
    let result=[];
    for(let i=0;i<users.length;i++){
        if(users[i].name.toUpperCase().indexOf(sub.toUpperCase()) > -1){
            let temp = await cquery(`select * from friendUser where userID = ${req.user.accountID} and friendID = ${users[i].userID};`);
            let temp2 = await cquery(`select * from friendRequest where requesterID = ${req.user.accountID} and requestedID = ${users[i].userID};`);
            let temp3 = await cquery(`select * from friendRequest where requestedID = ${req.user.accountID} and requesterID = ${users[i].userID};`);
            users[i].friend=0;
            if(temp.length){
                users[i].friend=1;
            }else if(temp2.length){
                users[i].friend=2;
            }else if(temp3.length){
                users[i].friend=3;
            }
            result.push(users[i]);
            console.log(users[i]);
        }
    }
    
    console.log(result);
    res.send(result);
})

router.post('/requestfriend', async (req,res)=>{
    let friendid = req.body.friendid;
    await cquery(`call sendFriendRequest(${req.user.accountID},${friendid});`);
    res.send({
        msg : 'done'
    })
} )

router.post('/unfriend',async (req,res)=>{
    let friendid = req.body.friendid;
    await cquery(`call unfriend(${req.user.accountID},${friendid});`);
    res.send({
        msg : 'done'
    })
})

router.post('/approvefriend', async (req,res)=>{
    let friendid = req.body.friendid;
    await cquery(`call approveFriendRequest(${req.user.accountID},${friendid});`);
    res.send({
        msg : 'done'
    })

})

router.post('/addreview', async (req,res)=>{
    let isbn = req.body.isbn;
    let review = req.body.review;
    console.log(isbn,review);
    await cquery(`call reviewBook(${req.user.accountID},'${isbn}','${review}');`);
    res.send({
        message: 'review added!'
    })
})

router.post('/getreviews', async (req,res)=>{
    let isbn = req.body.isbn;
    let reviews = await cquery(`call reviewsOfBook(${isbn});`);
    console.log(reviews);
    res.send(reviews[0]);
})

router.get('/aboutus',(req,res)=>{
    res.render(path+'about_us.ejs',{path : href,user : "user/"});
})

router.get('/contactus',(req,res)=>{
    res.render(path+'contact_us.ejs',{path : href,user: "user/"});
})

module.exports = router;