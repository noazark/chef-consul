name 'consul'
maintainer 'John Bellone'
maintainer_email 'jbellone@bloomberg.net'
license 'Apache v2.0'
description 'Installs/Configures consul'
long_description 'Installs/Configures consul'
version '0.5.1'

recipe 'consul', 'Installs and starts consul service.'
recipe 'consul::install_binary', 'Installs consul service from binary.'

supports 'ubuntu', '= 12.04'
supports 'ubuntu', '= 14.04'

depends 'ark'
depends 'golang', '~> 1.3.0'
