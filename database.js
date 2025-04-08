var db
function openDB(){
    db=LocalStorage.openDatabaseSync("temp","1.0","tempDB",1000)
}
function closeDB(){
    LocalStorage.closeDatabaseSync(db)
}
function initDBUserInfo(){
    db.transaction(function(tx)
    {
        tx.executeSql('CREATE TABLE IF NOT EXISTS userInfo(id INTEGER PRIMARY KEY, name TEXT, passwd TEXT)');
    }
    )
}
function readDBUserInfo(){
    if(!db){return}
    var result
    db.transaction(function(tx)
    {
         result = tx.executeSql('select * from userInfo')
    }
    )
    return result
}
function storeDBUserInfo(name,passwd){
    if(!db){return}
    db.transaction(function(tx)
    {
        tx.executeSql('INSERT INTO userInfo (name, passwd) VALUES (?, ?)',[name,passwd])
    }
    )
}
function updateDBUserInfo(id,name,passwd){
    if(!db){return}
    db.transaction(function(tx)
    {
        tx.executeSql('UPDATE userInfo SET name = ?, passwd = ? WHERE id = ?',[name,passwd,id])
    }
    )
}
function delDBUserInfo(id){
    if(!db){return}
    db.transaction(function(tx)
    {
        tx.executeSql('DELETE from userInfo where id=?',[id])
    }
    )
}
