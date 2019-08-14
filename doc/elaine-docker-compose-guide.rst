
========================================
ELAINE Docker Compose Installation Guide
========================================

This guide explains how to install ELAINE's CKAN instance for production/
deployment using Docker Compose. For development, the best way to install CKAN
is in a normal Docker container with a bind mount for easy access to the source
code - see https://gitlab.elaine.uni-rostock.de/INF/datahub/datahub-docker.
This guide is based on the instructions found at
https://docs.ckan.org/en/2.8/maintaining/installing/install-from-docker-compose.html.

---------------
1. Environment
---------------

a. Docker and Docker Compose

Docker should be installed system-wide using the official Docker CE installation
guide, found here: https://docs.docker.com/install/linux/docker-ce/ubuntu/.

To verify that Docker has been installed correctly, run `docker hello-world`.
Also, the command `docker version` should output version information for both
client and server.

Next, install Docker Compose system-wide following the official Docker Compose
installation guide, found here: https://docs.docker.com/compose/install/. To
verify successful installation, run `docker-compose version`.

b. CKAN

Clone ELAINE's fork of CKAN into any directory you prefer and checkout the
`elaine` branch.

.. code-block:: none

  cd /path/to/ckan
  git clone https://github.com/SFB-ELAINE/ckan.git
  git checkout elaine

-------------------------
2. Building Docker Images
-------------------------

a. Sensitive settings and environment variables

Copy `contrib/docker/.env.template` to `contrib/docker/.env` and follow the
instructions in the file to set passwords and other sensitive settings. Check
the original CKAN Docker Compose installation docs to see if your host OS
requires any specific configuration in this file.

b. Build images

Inside the CKAN directory:

.. code-block:: none

  cd contrib/docker
  docker-compose up -d --build

For the rest of the guide, all `docker-compose` commands should be run inside
`contrib/docker`.

On the first run, the postgres database container sometimes takes a long time to
initialize. If CKAN seems to be having trouble connecting to the database,
restart the ckan container a few times using `docker-compose restart ckan` and
view the container logs with `docker-compose logs -f ckan`.

After the containers are built and running and once the CKAN container has
connected to the database container, CKAN should be running at `CKAN_SITE_URL`
(localhost:5000 on Linux machines). `docker ps` should display five
running containers:

- `ckan`: CKAN with standard extensions plus ELAINE's extensions.
- `db`: CKAN's database.
- `redis`: A pre-built Redis image.
- `solr`: A pre-built SolR image set up for CKAN.
- `datapusher`: A pre-built CKAN Datapusher image.

There should also be four named Docker volumes (`docker volume ls | grep docker`),
each prefixed with the Docker Compose project name (`docker` by default;
value of `COMPOSE_PROJECT_NAME` if it is set).

- `docker_ckan_config`: Home of production.ini.
- `docker_ckan_home`: Home of CKAN virtual environment and source, as well as
CKAN extensions.
- `docker_ckan_storage`: Home of CKAN's filestore (resource files)
- `docker_pg_data`: home of the database files for CKAN's default and datastore
databases.

The location of these named volumes needs to be backed up in a production
environment. The CKAN Docker Compose installation guide also details the process
of migrating CKAN data between different CKAN hosts.

For convenience during installation, we'll define environment variables for the
paths to the config, home, and storage volumes so that they are easy to access later
(we won't need to access the database volume).

.. code-block:: none

  # Find the path to a named volume
  docker volume inspect docker_ckan_home | jq -c '.[] | .Mountpoint'
  # "/var/lib/docker/volumes/docker_ckan_config/_data"

  export VOL_CKAN_HOME=`docker volume inspect docker_ckan_home | jq -r -c '.[] | .Mountpoint'`
  echo $VOL_CKAN_HOME

  export VOL_CKAN_CONFIG=`docker volume inspect docker_ckan_config | jq -r -c '.[] | .Mountpoint'`
  echo $VOL_CKAN_CONFIG

  export VOL_CKAN_STORAGE=`docker volume inspect docker_ckan_storage | jq -r -c '.[] | .Mountpoint'`
  echo $VOL_CKAN_STORAGE

---------------------------
3. Datastore and Datapusher
---------------------------

To enable datastore, the datastore database users have to be created, and we
need to enable the datastore and datapusher settings in `production.ini`. The
`elaine` branch's `contrib/docker/ckan-entrypoint.sh` file automatically
enables the datastore and datapusher settings in `production.ini`, so we
only need to execute a few built-in scripts against the `db` container to
finish enabling them.

.. code-block:: none

  docker exec -it db sh /docker-entrypoint-initdb.d/00_create_datastore.sh
  docker exec ckan /usr/local/bin/ckan-paster --plugin=ckan datastore set-permissions -c /etc/ckan/production.ini | docker exec -i db psql -U ckan

The first script creates the datastore database and a readonly user in the `db`
container. The script may throw an error and say that the `datastore_ro` user already
exists; this is fine. The second script is the output of `paster ckan set-permissions`;
however, as this output can change in future versions of CKAN, we set the
 permissions directly. The effect of these scripts is persisted in the named
 volume `docker_pg_data`.

`datastore` and `datapusher` have automatically been added to `ckan.plugins`;
HOWEVER, you must **manually** enable the datapusher option
`ckan.datapusher.formats`. The remaining settings required for datastore and
datapusher have already been taken care of by the images. You can edit
the production.ini directly on the host using `sudo vim $VOL_CKAN_CONFIG/production.ini`
or `sudo emacs $VOL_CKAN_CONFIG/production.ini`.

Restart the `ckan` container with `docker-compose restart ckan`. If everything
is set up correctly, CKAN_SITE_URL/api/3/action/datastore_search?resource_id=_table_metadata
will return content.

-------------------------
4. Create CKAN Admin User
-------------------------

With all containers up and running, create the CKAN admin user (johndoe in
this example):

.. code-block:: none

  docker exec -it ckan /usr/local/bin/ckan-paster --plugin=ckan sysadmin -c /etc/ckan/production.ini add johndoe

You will now be able to log into your instance of CKAN. The admin's API key
will be necessary in migrating data from another instance of CKAN.

-----------------
5. Migrating Data
-----------------
See https://docs.ckan.org/en/2.8/maintaining/installing/install-from-docker-compose.html#migrate-data
for instructions on migrating data.

-------------
6. Extensions
-------------

The Dockerfile and `ckan-entrypoint.sh` script in the `elaine` branch automatically
install and enable ELAINE's extensions. Currently, they install the following:

- Disablepwreset extension (https://github.com/SFB-ELAINE/ckanext-disablepwreset)
  from commit #37074f7.
- Elaine_theme extension (https://github.com/SFB-ELAINE/ckanext-elaine_theme)
  from the most recent commit.
- PDFview extension (https://github.com/ckan/ckanext-pdfview) from the branch
  `31-fix-flask-exception` (https://github.com/hayley-leblanc/ckanext-pdfview/tree/31-fix-flask-exception).
  The current master version of this extension has a bug that causes server errors
  in more recent versions of CKAN that use Flask rather than Pylons; this branch
  fixes that issue for the version of CKAN that our instance runs on, but has
  not been merged to the master branch yet.
- Privatedatasets extension (https://github.com/SFB-ELAINE/ckanext-privatedatasets)
  from SFB-ELAINE branch `elaine-new-version`.
- Videoviewer extension (https://github.com/TIBHannover/ckanext-videoviewer)
  from the most recent commit.
- Papaya extension (https://github.com/SFB-ELAINE/ckanext-papaya) from the most
  recent commit.
- VTK.js extension (https://github.com/SFB-ELAINE/ckanext-vtkjs) from the most
  recent commit.

None of these extensions need any further configuration.

If you are transferring in data from a CKAN instance that did not have all of
the view extensions that this one does, you can run the `paster views create`
command to create views for the migrated resources.
To access a bash shell in the CKAN container and access its virtual environment
(both of which are necessary for this `paster` command), run the following
while all containers are up and running:

.. code-block:: none

  docker exec -it ckan /bin/bash -c "export TERM=xterm; exec bash"
  source $CKAN_VENV/bin/activate && cd $CKAN_VENV/src/ckan

Now follow these instructions to use the `paster` command:
https://docs.ckan.org/en/2.8/maintaining/data-viewer.html#migrating-from-previous-ckan-versions.

If more extensions need to be added, you could follow the instructions in the
CKAN Docker Compose installation guide (https://docs.ckan.org/en/2.8/maintaining/installing/install-from-docker-compose.html#add-extensions)
to manually install the extension in the `ckan` container once it has been built.
If you would like the extension to be installed automatically on future builds
of the containers, you should be able to add a line to `pip install` the
extension in the Dockerfile and add a few lines in `ckan-entrypoint.sh` to
set the correct configuration settings, then rebuild the images; however, this
has not been tested.
