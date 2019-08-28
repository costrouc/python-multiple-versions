# Demo of Multiple Python Versions

This is a self contained demo of having multiple versions of a python
package in the same `PYTHONPATH`. It requires
[nix](https://nixos.org/nix/) (sorry no windows support in nix). This
idea is not nix specific but would rely on package managers/builds to
allow for multiple versions.

```shell
$ nix-shell
...
[nix-shell:~/p/python-multiple-versions]$ python
Python 3.7.4 (default, Jul  8 2019, 18:31:06) 
[GCC 7.4.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import foobar; foobar.foobar()
I am using flask version 1.0.3
>>> import bizbaz; bizbaz.bizbaz()
I am using flask version 0.12.4
>>> quit()
$ echo $PYTHONPATH
...:/nix/store/f3j11lk2m8ddw2j2axvcdfc2al2bk98c-flask-0.12.4/lib/python3.7/site-packages:.../nix/store/wv42si07c8wd64ravd4va4kh4j7prwlk-python3.7-Flask-1.0.3/lib/python3.7/site-packages:...
```

## Motivation

In [nixpkgs](https://github.com/NixOS/nixpkgs) we like to have a
single version of each package (preferably latest) with all packages
compatible with one another. Often times it is true that two packages
may be incompatible with one another but if it is a compiled
library/binary we have luxury of rewriting the shared library path
allowing two packages that use different versions of a package to
coexist. In python this philosophy breaks down because all packages
are specified in the global `PYTHONPATH`. This means that if a package
requires `import flask` it searches the path for flask and uses the
one that it finds. 

For nixpkgs this is troublesome because it prevents all packages from
being compatible with one another. 

### Examples of Issue

1. `jsonschema`. [jupyterlab_server](https://github.com/jupyterlab/jupyterlab_server/blob/master/setup.py#L44)
   requires `jsonschema >= 3.0.1` and `cfn-python-lint` did not
   support jsonschema 3 until [about a month
   ago](https://github.com/aws-cloudformation/cfn-python-lint/commit/0ff876934e9ed093785876e976fb13b64a1b8eb4#diff-2eeaed663bd0d25b7e608891384b7298). 3.0
   was [released in
   February](https://github.com/Julian/jsonschema/commit/21838cd7727bd7c1d9a309df51cd32ebb0c78cdb)!

2. Some packages fix the version of a package such that other packages
   in the same PYTHONPATH cannot depend on the latest version. For
   example `apache-airflow` fixes [pendulum ==
   1.4.4](https://github.com/apache/airflow/blob/master/setup.py#L349). That
   pendulum release is over 1.5 years old and
   [libraries.io](https://libraries.io/pypi/pendulum) reports that
   400+ packages depend on pendulum. We cannot let a single package
   restrict the version of other packages.

## How does this work?

I wrote a tool [python-rewrite-imports](https://github.com/nix-community/nixpkgs-pytools/#python-rewrite-imports) that helps to make multiple versions possible. Lets say that package `bizbaz` wants an old version of `flask==0.12.4` but we have another package `foobar` that requires the latest version of `flask>=1.0`. Normally these two packages would be incompatible. In order to do this we:

1. Create a build of `flask` for 0.12.4 and install
2. Use [Rope](https://github.com/python-rope/rope) to rewrite all the imports of flask of itself to `flask_0_12_4_1pamldmw2y7g` and rename the package to `flask_0_12_4_1pamldmw2y7g`
3. Rename the `dist` in site-packages and move the package to `flask_0_12_4_1pamldmw2y7g`
4. Rewrite all imports of `flask` in `bizbaz` to `flask_0_12_4_1pamldmw2y7g`

Rewriting all imports is done with
[Rope](https://github.com/python-rope/rope) a robust python
refactoring tool.

## Current Limitations

 - Wanting several versions of a package that builds c-extensions
   looks a little hard than rewriting the imports?
 - Suppose package A requires `C==1.0.0` and B requires
   `C>=1.1`. Let's say that package B calls a method in A with a
   structure built from `C>=1.1` and then A proceeds to call its
   package C with that data. This will probably not happen often.
 - Rope does not handle all rewrites currently in
   python 3. Expressions within `fstrings` are the only example that I
   know of.
 - It is impossible for Rope to handle all import rewrites. For
   example. `import flask; globals()[chr(102) + 'lask'].__version__`

I believe for the vast majority of packages that require multiple
versions these issues will be rare.
