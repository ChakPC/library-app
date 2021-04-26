const router = require('express').Router();
const path = '../views/common/';
const passport = require('passport');
const domain = require('./domain')
const href = domain.href;
const bcrypt = require('bcrypt');
const keys = require('../keys');
const saltRounds = keys.salt;

const hash = async(pass) => {
    return new Promise ((resolve,reject)=>{
        bcrypt.hash(pass,saltRounds,(err,hash)=>{
            resolve(hash);
        })
    })
}

const compare = async(pass,hash) => {
    return new Promise((resolve,reject)=>{
        bcrypt.compare(pass,hash,(err,result)=>{
            resolve(result);
        })
    })
}

const cquery = async (sql, req, res) => {
    return new Promise((resolve, reject) => {
        connection.query(sql, (err, result) => {
            if (err) throw err;
            resolve(result);
        })
    }
    )
}

router.get('/login', async (req, res) => {
    let temp = await hash('abc');
    console.log(temp);
    if (req.user) {
        if (req.user.accountType == 'librarian') {
            res.redirect('/librarian/home');
        } else {
            res.redirect('/user/home');
        }
    } else {
        let error = req.flash('error');
        let message = req.flash('message');
        res.render(path + 'login', { path: href, error, message });
    }
});

router.post('/login', passport.authenticate('local', { failureRedirect: '/auth/login', failureFlash: true, passReqToCallback: true }), async (req, res) => {
    let id = req.user.accountID;
    let temp = await cquery(`select accountType from account where accountID = ${id};`);
    console.log('here', temp);
    if (temp[0].accountType == 'librarian') {
        res.redirect('/librarian/home');
    } else {
        res.redirect('/user/home');
    }
})

router.get('/logout', (req, res) => {
    req.logout();
    res.redirect('/');
})

router.get('/google', passport.authenticate('google', {
    scope: ['profile', 'email']
}))

router.get('/signup', (req, res) => {
    let name = req.query.name;
    let email = req.query.email;
    let error = req.flash('error');
    res.render(path + 'signup', { name, email, path: href, error });
})

router.post('/signup', async (req, res) => {
    let name = req.body.name;
    let email = req.body.email;
    let address = req.body.address;
    let type = req.body.type;
    let pass = req.body.password;
    let repass = req.body.repassword;
    console.log(req.body);
    if (pass != repass) {
        req.flash('error', 'passwords do not match');
        res.redirect(`/auth/signup/?name=${name}&email=${email}`);
    } else {
        let flag = await cquery(`select * from account where email = '${email}';`, req, res);
        if (flag.length) {
            req.flash('error', 'email is already registered');
            res.redirect(`/auth/signup/?name=${name}&email=${email}`);
        } else {
            pass = await hash(pass);
            let temp = await cquery(`call signUpUser('${email}','${pass}','${name}','${address}','${type}',@did);`);
            req.flash('message', 'You are signed up now. Please login.');
            res.redirect('/auth/login');
        }
    }
})

router.get('/google/redirect', passport.authenticate('google'), async (req, res) => {
    // console.log(err,'here');
    console.log(req.user);
    console.log(req.added);
    if (req.added == false) {
        req.logout();
        res.redirect('/auth/signup?' + 'name=' + req.name + "+" + req.fname + '&email=' + req.email);
        // req.logout();
    } else {
        let id = req.user.accountID;
        let temp = await cquery(`select accountType from account where accountID = ${id};`);
        console.log('here', temp);
        if (temp[0].accountType == 'librarian') {
            res.redirect('/librarian/home');
        } else {
            res.redirect('/user/home');
        }
    }
})

module.exports = router;