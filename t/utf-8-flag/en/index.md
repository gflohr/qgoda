---
lingua: de
location: /en/index.html
month: March
title: Hello, world!
---
<!--qgoda-no-xgettext-->[% USE q = Qgoda %]<!--/qgoda-no-xgettext-->

config.title: [% config.title %]

month: [% asset.month %]

full date: [% q.strftime('%B', -120067740, asset.lingua) %]

98.96 °F in the morning.
