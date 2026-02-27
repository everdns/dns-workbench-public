sudo named-checkconf
sudo named-checkzone wi.lan db.wi.com

dig @10.10.1.1 wi.lan ANY +noall +answer +authority +additional
