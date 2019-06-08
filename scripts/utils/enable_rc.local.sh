#!/bin/bash

# Declare variable for /etc/rc.local
rc_local=/etc/rc.local

# Verify if exists /etc/rc.local
if [[ ! -f "$rc_local" ]]; then
    # Create default /etc/rc.local
    sudo printf '%s\n' '#!/bin/bash' '' 'exit 0' > $rc_local
fi

# Add permission for execution if missing
sudo chmod +x $rc_local