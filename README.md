![Travis (.org)](https://img.shields.io/travis/gflohr/qgoda.svg)

# Qgoda

Qgoda (pronounce: yagoda!) is an extensible static site generator.

## Description

Qgoda is considered feature-complete and ready for beta testing.
Incompatible changes will try to be avoided but are possible.

The documentation is currently being written.  You can check out the
current state at http://www.qgoda.net/.

## Main Features

Qgoda is comparable to [Jekyll](https://jekyllrb.com/) 
or [Hugo](https://gohugo.io/) but with a strong focus on:

- Flexible site structures with arbitrary taxonomies.
- Listings with pagination for arbitrary taxonomies and filters.
- Extensibility with plug-ins written in Perl, Python, Ruby,
  or Java.
- Built-in multi-language features based on GNU gettext, both
  for template code and --- optionally --- for content.
- Integration of tools from the NodeJS eco system such as
  [npm](https://www.npmjs.com/), [yarn](https://yarnpkg.com/),
  [webpack](https://webpack.js.org/), [Gulp](https://gulpjs.com/),
  [Browsersync](https://www.browsersync.io/), [PostCSS](http://postcss.org/),
  ...
- Integration of arbitrary other tools and helpers.

## Template Languages

Qgoda uses [Markdown](https://daringfireball.net/projects/markdown/syntax)
and the [Template Toolkit](http://www.template-toolkit.org/) by default for
processing content, although it is possible to change that.

## Run Qgoda in Docker Container

Due to missing dependencies, you may have problems installing and running
Qgoda on your platform (especially on Microsoft Windows systems).  You can
instead try using a Qgoda Docker image:

1. Install Docker.  On Linux/Unix systems, Docker will be available from
your package manager.  On Mac OS X you can install Docker with Mac Ports
or Homebrew.  On Windows, get a pre-compiled binary from
https://www.docker.com/get-docker.

2. Start Docker.  You may want to start the docker daemon automatically.
Check your vendor's documentation for that!

3. In a shell, run `docker run --rm -it -v $(pwd):/data gflohr/qgoda`.  
You may have to add the user that runs the command to the group "docker"
if you get an error like "permission denied".

4. You may want to create an alias, so that you do not have to type in
the Docker commands all the time.  Depending on your operating system,
you have to open `~/.bash_profile`, `~/.bashrc`, `~/.alias`, `~/.zshrc`
or similar and add this line:

```bash
alias qgoda='docker run --rm -it -v $(pwd):/data gflohr/qgoda'
```

## Contribute

Qgoda uses [Github](https://github.com/) as the collaboration platform.
Fork the [Qgoda repository](https://github.com/gflohr/qgoda) and send
a pull request with your changes.

Apart from adding or fixing Perl code, the following contributions are
welcome:

* Corrections to the documentation.  Please use the
[github repository issue tracker](https://github.com/gflohr/qgoda-site/issues)
for errors that you have found.
* Translate Qgoda to your language.  Please use the [Qgoda issue
tracker](https://github.com/gflohr/qgoda/issues) for getting in
touch first.
* Contribute a new Qgoda theme!  You can use one of the following
github repositories for examples:
    * https://github.com/gflohr/qgoda-default
    * https://github.com/gflohr/qgoda-multilang
    * https://github.com/gflohr/qgoda-essential
    * https://github.com/gflohr/qgoda-minimal
* [Star qgoda's github repository](https://github.com/gflohr/qgoda/stargazers).  This will also push up
Qgoda (and Perl and Template Toolkit) on the staticgen.com.

## Copyright

Copyright (C) 2016-2018 Guido Flohr <guido.flohr@cantanea.com>, all
rights reserved.

Qgoda is available under the terms and conditions of the GNU General
Public License version 3 or later.
