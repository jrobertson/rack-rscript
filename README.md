Introducing the Rack-Rscript gem

## Example

First of all install rack-rscript and then create a file called hello_world2.ru containing the following:

    require 'rack-rscript'

    run RackRscript.new({pkg_src: 'http://rorbuilder.info/r'})

The file is executed using rackup e.g. `rackup hello_world2.ru -p 3000`

## Observation

When navigating to the address http://127.0.0.1:3000/do/utility/time in your web browser you should observe the date and time is returned from the request.

