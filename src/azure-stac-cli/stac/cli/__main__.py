# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

import sys
from core import get_default_cli

def cli_main(cli, args):
    return cli.invoke(args)

# instantiation our stac cli here
stac_cli = get_default_cli()


try:
    
    # invoke the stac cli and pass the arguments to it
    exit_code = cli_main(stac_cli, sys.argv[1:])
    
except KeyboardInterrupt:
    
    # if there is a keyboard interruption, then exit with code 1
    sys.exit(1)
    
except SystemExit as ex:
    
    # if there system exit, then use the exit code in the exception
    # otherwise, use exit code 1 if there is no exit code in the 
    # exception being thrown
    exit_code = ex.code if ex.code is not None else 1
    raise ex
