## Fluree Schema Scenario Tool

This project contains a simple yet usefull tool for database schema development for FlureeDB.
The tool has three main uses:

1) Compile a FlureeDB schema from multiple sources.
2) Deploy a FlureeDB schema compiled from multiple sources.
3) Run unit-tests on the different components of the FlureeDB schema.

The first version of the tool is just the python script *fsst*. In the near future, a Dockerfile will be added to make integration of the tool in CICD pipelines more convenient.

### Dependencies

Prior to using the *fsst* tool, use *pip install* to install all dependencies.

```bash
python3 -m pip install base58 aioflureedb bitcoinlib
```

### Project directory structure.

The directory *demo-schema-parts* contains a sample project directory structure. 
When invoking *fsst*, a directory should be specified with the *--dir* option. This directory should contain a file named *build.json* with a structure as below:

```json
{
    "default": [
        "roles",
        "there_can_be_only_one"
    ]
}
```

In this file *default* is the one and only build *target*. A build.json should always have a *default* defined, but can define other build targets as well. When invoking *fsst*, normally the *default* build target will be used. This can be overruled by specifying the *--target* option.

Each build target specifies a list of build *steps*. In the example above, we have two *steps*, the step "roles" and the step "there\_can\_be\_only\_one". For each step, either a json file or a *step directory* should exist. The most basic definition of a step is simply a json file with Fluree transactions in a JSON array. No extra processing is done on such files, the transactions are simply added as is.

Things are different for *step directories*. A step directory must contain a JSON file named *main.json*. This file can, just like the JSON file we just mentioned, just a list of as-is FlureeDB transactions, but the operations inside the transactions may also contain one or more of special *pre-processing fields*, that we will get to in the section *operation expansion*. 

Next to the file *main.json*, a *step directory* may contain the file *test.json*. This file looks something like this:

```json
[
  "test1"
]
```

The file contains a simle JSON array of strings. Each string in the array designates a *test scenario* for the build step. Each test scenario directory could contain the following files:

* user.json
* prepare.json
* yes.json
* no.json
* tyes.json
* tno.json
* cleanup.json

The *user.json* and *prepare.json* files are mandatory. The other ones are optional. We'll discuss the content of these files in the *testing* section below.

### Operation expansion

This functionality comes in handy mostly when working on data centric security with FlureeDB. FlureeDB comes with a really powerfull access control feature that allows queries and transactions to be guarded by so called smart functions. Smart functions are written in a subset of the Clojure/ClojureScript language. Queries and transactions though are written in FlureeQL JSON. The clojure code needs to be put in JSON strings, and often the FlureeQL JSON needs to be first chopped up and put into Clojure expressions. The *fsst* tool comes with three pre-processing keys for transaction operations that help ease this process.

#### The code\_from\_query key

The use of this key can best be shown:
```json
{
    "name" : "roleCount",
    "code_from_query" : {
      "select": ["(count ?auth)"],
      "where":[
        ["?roles", "_role/id", "PARAM"],
        ["?auth", "_auth/roles", "?roles"]
      ]
    },
    "doc" : "Retrieve count for a specific role",
    "_id" : "_fn$roleCount",
    "params" : ["myRole"]
  }
```
The above will be pre-processed by the *fsst* tool into the operation below:
```json
{
    "name": "roleCount",
    "doc": "Retrieve count for a specific role",
    "_id": "_fn$roleCount",
    "params": ["myRole"],
    "code": "(query (str  \"{\\\"select\\\": [\\\"(count ?auth)\\\"], \\\"where\\\": [[\\\"?roles\\\", \\\"_role/id\\\", \\\"\" myRole \"\\\"], [\\\"?auth\\\", \\\"_auth/roles\\\", \\\"?roles\\\"]]}\" ) )"
}
```
It is important to note that in case of more than one parameter, the source operation should possibly use sorted JSON keys in order to avoid unexpected substitution. 
#### The code\_expand key
While not as problamatic to escape manually as the example above, it can be usefull to keep hand-written clojure in seperate clojure files.

That means we can put the following in main.json:
```json
{
    "name" : "roleAssignedHeadOfState?",
    "code_expand" : "roleAssignedHeadOfState.clj",
    "_id" : "_fn$roleAssignedHeadOfState",
    "doc" : "Is the role HeadOfState Assigned to 0 or 1 Auths?"
}
```
And put the clojure into roleAssignedHeadOfState.clj:
```lisp
(<= (nth (roleCount "headofstate") 0) 1)
```
This will get expanded to
```json
{
    "name" : "roleAssignedHeadOfState?",
    "code" : "(<= (nth (roleCount \"headofstate\") 0) 1)",
    "_id" : "_fn$roleAssignedHeadOfState",
    "doc" : "Is the role HeadOfState Assigned to 0 or 1 Auths?"
}
```
#### The COMMENT key
This one is mostly meant for tests. As JSON doesn't come with any possibility to add comments, we allow the key COMMENT
to be added to operations. The *fsst* tool will strip out all ocurences of COMMENT keys in operations and queries.

### Compile a FlureeDB schema from multiple sources
When used in CICD, invoking fsst this way creates a single JSON file with an array of transactions for FlureeDB.
```bash
./fsst --dir demo-schema-parts --output fluree_artifact.json
```
If needed specify an alternate build target.
```bash
./fsst --dir demo-schema-parts --output fluree_artifact_other.json --target other
```

### Deploy a FlureeDB schema compiled from multiple sources.
When used for local testing, it can be usefull to push the created schema directly to a FlureeDB host.

```bash
./fsst --dir demo-schema-parts --notest --host localhost --port 8090 --network testnet --createkey 4bb3d9f9f99281be4699859afdb39270083305414ae6506179a20e58c678f513
```

We need to specify some info about the local FlureeDB host. Note the *--test* option that specifies we don't want to run test scenarios. The *--network* option specifies the FlureeDB network string that together with the target (default in this case) ends up making up the database name. The --createkey option should specify the default instalation key of your local FlureeDB instance.

### Run unit-tests on the different components of the FlureeDB schema.

The third way to use *fsst* is as a unit test framework for the different test scenarios defined in the steps. To invoke *fsst* in this way, we call it like this:

```bash
./fsst --dir demo-schema-parts --host localhost --port 8090 --createkey 4bb3d9f9f99281be4699859afdb39270083305414ae6506179a20e58c678f513
```

What happens when we run the tool like this?

Well, for every step in the selected build, *fsst* will do the following:

1) Create a new database
2) Fill the database with the expanded schema up untill the parts defined in that step
3) For each of the tests defined for the step :
    1) Read the user.json file as test transaction config
    2) Run all transactions defined in prepare.json
    3) Run all queries in yes.json, fail+abandon if any of the queries returns an empty array
    4) Run all queries in no.json, fail+abandon if any of the queries returns a non-empty array.
    5) Run all tyes transactions, fail+abandon if any of the transactions returns an error.
    6) Run all tno transactions, fail+abandon if any of the transactions doesn't returnh an error.
    7) Run all transactions in cleanup.json

We should shortly discuss user.json and prepare.json. The file *user.json* looks something like this:

```json
{
   "keys" : [
      {
         "account-id" : "TeyTH5RdmweiWzrkEzwc5vYnPwqZDSh8Ng6",
         "private" : "bb19048fbfc8f6a7f02b336048fa8e5aba1fb87f55893d40ff1ba375b90a8398"
      }
   ],
   "no" : 0,
   "yes" : 0,
   "tno": 0,
   "tyes": 0
}
```
The JSON above tels *fsst* to run all transactions in tyes.json and tno.json and all queries in yes.json and no.json using the key at index zero of the keys array. It is possible to specify key usage more granular by using an array instead of an integer, to for example have two yes queries run with key zero and the next two with key one.

It is important to note that *fsst* doesn't create *_auth* records for the keys in user.json automatically. This should be done in prepare.json in a transaction like this:

```json
[
    {
      "_id": "_auth",
      "id": "TeyTH5RdmweiWzrkEzwc5vYnPwqZDSh8Ng6",
      "roles": [["_role/id","root"]]
    }
  ]
```


