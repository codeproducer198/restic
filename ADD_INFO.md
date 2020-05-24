# Restric additional infos

This based on v0.9.6.

## New Features

Support of local key-files:
`export RESTIC_KEYSPATH="/home/restic/config"`

Support of follow symbolic links:
`export RESTIC_FOLLOWSLINK="Y"`

## Build

Add go to PATH `export PATH=$PATH:/usr/local/go/bin`

Normal build without debug-log
```
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "-s -w" -o restic_linux_amd64 ./cmd/restic
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -ldflags "-s -w" -o restic_linux_arm64 ./cmd/restic
```

Build with debug-log
`GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "-s -w" -tags selfupdate -tags debug -o restic_linux_amd64 ./cmd/restic`
The logfile is witten to `log.txt`

## Commands

Backup

	./restic_linux_amd64 -r /home/lxstore/tmp/test5 backup /home/lxstore/tmp/restic_backup/data/ --exclude-file=$RESTIC_KEYSPATH/excludes.txt

Restore

	./restic_linux_amd64 -r /home/lxstore/tmp/test5 restore latest --target /home/thomas/programming/projekte/go/restic/restore
	./restic_linux_amd64 -r /home/lxstore/tmp/test5 mount /mnt/restic

Inspect

	./restic_linux_amd64 -r /home/lxstore/tmp/test5 ls -l latest
	./restic_linux_amd64 -r /home/lxstore/tmp/test5 snapshots
	./restic_linux_amd64 -r /home/lxstore/tmp/test5 diff 483709dd 6f873568
	./restic_linux_amd64 -r /home/lxstore/tmp/test5 cat masterkey
	./restic_linux_amd64 -r /home/lxstore/tmp/test5 cat snapshot 6f873568

Maintaince

	./restic_linux_amd64 -r /home/lxstore/tmp/test5 forget --prune --keep-last 1
	./restic_linux_amd64 -r /home/lxstore/tmp/test5 forget --prune <snapshot-id>

## Wrapper

To use restric and the environment variables simply there is a wrapper bash-script `wrapper/restic.sh` and a configuration `wrapper/restic.conf`.
First copy the `restic.conf.template` to `restic.conf` and change it to your configuration.
To use the script change to `wrapper` folder and run `./restic.sh`. The first parameter is the profile and the next parameters are the restric
parameters (like "key list" or "backup ...").

This wrapper uses the `RESTIC_FOLLOWSLINK="Y"` and the local keys `RESTIC_KEYSPATH`.
So you need a folder with the following content where the `RESTIC_KEYSPATH` is pointing:
- keys/<restric-key-file>
- excludes.txt (restric excludes)
- hidrive.id (Private SSH Key)
- pw_<profile>.txt (content is the restric master password)

## Connectionprobleme / DSL Zwangstrennung

Mit der Zwangstrennung kommt es zu einem Abbruch der Übertragung. Der Code sieht zwar eine _retry_ vor, aber das scheint nicht zu klappen wenn die
Verbindung "gekappt" wird.

In `internal/backend/ftp/sftp.go` in `startClient()` wird ein command `ssh sftp.hidrive.strato.com -l user -i privKey.id -s sftp` zusammengebaut, 
der als eigener Subprozess gestartet wird und der StdIn/-Out/-Err hört und auf den der `sftp.NewClientPipe()` gesetzt wird.
Bricht die Verbindung ab, verschwindet auch der `ssh` Prozess bzw. es kommt der Fehler

	subprocess ssh: packet_write_wait: Connection to 85.214.3.70 port 22: Broken pipe

In `internal/backend/backend_retry.go` wird zwar mit Hilfe von _backoff_  der Retry implementiert, der greift aber nicht in dem Fall - wieso keine Ahnung.

Ich habe erst mit den Zeiten der Retries rumexperimentiert, weil ich das von `duply` kenne, dass in der Zwangstrennung es nichts bringt 5 Sekunden später weiterzumachen.
In `internal/backend/backend_retry.go` bei der Methode `retry` kann man das `backoff.NewExponentialBackOff()` erzeugen und parametrisieren:

	// start with 10 seconds and end with 10 minutes
	eb := backoff.NewExponentialBackOff()
	eb.InitialInterval = 10 * time.Second
	eb.Multiplier      = 1.57
	eb.MaxInterval     = 10 * time.Minute
	eb.MaxElapsedTime  = 10 * time.Minute
	...
	backoff.WithContext(backoff.WithMaxRetries(eb, uint64(be.MaxTries)), ctx),

Lokal kann man den Verbindungsabbruch testen, wenn man mit `sudo tcpkill host 85.214.3.70` die Verbindung kappt.

In `sftp.go` habe ich die Logik vom ssh-Command auf ohne externen Prozess umgestellt, verhalten beim Abbruch war das selbe -> kein Wiederaufbau.
```java
func newClientX() (*sftp.Client, error) {
  addr := "sftp.hidrive.strato.com:22"
  config := &ssh.ClientConfig{
    User: "myuser",
    Auth: []ssh.AuthMethod{
      ssh.Password("???"),
    },
	HostKeyCallback: func(hostname string, remote net.Addr, key ssh.PublicKey) error {
        return nil
    },    
    //Ciphers: []string{"3des-cbc", "aes256-cbc", "aes192-cbc", "aes128-cbc"},
  }
  conn, err := ssh.Dial("tcp", addr, config)
  if err != nil {
    panic("Failed to dial: " + err.Error())
  }
  client, err := sftp.NewClient(conn)
  if err != nil {
    panic("Failed to create client: " + err.Error())
  }
  return client, err
}
```
