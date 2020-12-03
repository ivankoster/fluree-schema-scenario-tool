## Fluree Schema Scenario Tool

This project contains a simple yet usefull tool for database schema development for FlureeDB.
Note that there have been major updates to the commandline interface from the 0.1 version of this tool. Please upgrade both the tool and the accompanying [docker images](https://hub.docker.com/r/pibara/fsst/tags?page=1&ordering=last_updated) if you are currently using the 0.1 version.

From the 0.2 version of *fsst*, the command line has a number of sub commands. 
The following sub-commands run without docker and without a local FlureeDB server.

* [version](doc/version.MD) : Print the *fsst* version
* [artifact](doc/artifact.MD) : Compile a single file FlureeDB schema from multiple sources.

The following sub-commands can run without docker, but need a FlureeDB server to communicate with

* [artifactdeploy](doc/artifactdeploy.MD) : 
* [deploy](doc/deploy.MD)
* [test](doc/deploy.MD) 

If you have Docker installed, the following commands should also be available

* [versioncheck](doc/versioncheck.MD) : Compare the version of the fsst tool on the host with the one on the guest docker for compatibility.
* [dockerstart](doc/dockerstart.MD) : Start a FlureeDB version in a docker container.
* [dockerstop](doc/dockerstop.MD) : Stop docker container running given FlureeDB version.
* [dockerparams](doc/dockerparams.MD) : Retreive base info from a running docker container running a given FlureeDB version.
* [dockerdeploy](doc/dockerdeploy.MD)
* [dockertest](doc/dockertest.MD)

### Dependencies

Prior to using the *fsst* tool, use *pip install* to install all dependencies.
Note that these dependencies should not be needed if you only intent to use the unit-test (using docker) or the docker temp instance of Fluree.

```bash
python3 -m pip install base58 aioflureedb bitcoinlib docker
```

It is important to note that as some dependencies are only needed for some subcommands, it is possible to run *fsst* without some of the dependencies installed, but doing so will disable several subcommands.

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

