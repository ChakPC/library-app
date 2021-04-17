const router = require('express').Router();
const path = '../views/user/';
const href = 'http://localhost:5000/';


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


router.get('/home',async (req,res)=>{
    let userid=req.user.accountID;
    let temp = await cquery(`select name,address from user where userID=${userid};`);
    let name = temp[0].name;
    let address = temp[0].address;
    console.log(temp);
    res.render(path+'user_home.ejs',{path : href,name,address,userid});
});

router.get('/temp',(req,res)=>{
    res.render(path+'temp',{path : href});
})

module.exports = router;