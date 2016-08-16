echo "#!/bin/bash
# Sets permissions of the owncloud instance for updating

ocpath="OWNCLOUDPATH"
htuser="www-data"
htgroup="www-data"

chown -R ${htuser}:${htgroup} ${ocpath}
