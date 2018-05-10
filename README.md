# Qgoda

Qgoda (pronounce: yagoda!) is an extensible static site generator.

## Description

Qgoda is considered feature-complete but still under heavy development.

The documentation is currently being written.  You can check out the
current state at http://www.qgoda.net/.

## Main Features

Qgoda is comparable to [Jekyll](https://jekyllrb.com/) 
or [Hugo](https://gohugo.io/) but with a strong focus on:

- Flexible site structures with arbitrary taxonomies.
- Listings with pagination for arbitrary taxonomies and filters.
- Extensibilities with plug-ins written in Perl, Python, Ruby,
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

2. In a shell, run:

```bash
$ docker run --rm -it -v $(pwd):/data dsonntag/qgoda
```

3. You may want to create an alias, so that you do not have to type in
the Docker commands all the time.  Depending on your operating system,
you have to open `~/.bash_profile`, `~/.bashrc`, `~/.alias`, `~/.zshrc`
or similar and add this line:

```bash
alias qgoda="docker run --rm -it -v $(pwd):/data dsonntag/qgoda"
```

## Copyright

Copyright (C) 2016-2017 Guido Flohr <guido.flohr@cantanea.com>, all
rights reserved.

Qgoda is available under the terms and conditions of the GNU General
Public License version 3 or later.
