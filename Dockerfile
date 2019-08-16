# See CKAN docs on installation from Docker Compose on usage
FROM debian:stretch
MAINTAINER Open Knowledge

# Install required system packages
RUN apt-get -q -y update \
    && DEBIAN_FRONTEND=noninteractive apt-get -q -y upgrade \
    && apt-get -q -y install \
        python-dev \
        python-pip \
        python-virtualenv \
        python-wheel \
        libpq-dev \
        libxml2-dev \
        libxslt-dev \
        libgeos-dev \
        libssl-dev \
        libffi-dev \
        postgresql-client \
        build-essential \
        git-core \
        vim \
        wget \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*

# Define environment variables
ENV CKAN_HOME /usr/lib/ckan
ENV CKAN_VENV $CKAN_HOME/venv
ENV CKAN_CONFIG /etc/ckan
ENV CKAN_STORAGE_PATH=/var/lib/ckan
ENV PATH="$CKAN_VENV/bin:$PATH"


# Build-time variables specified by docker-compose.yml / .env
ARG CKAN_SITE_URL

# Create ckan user
RUN useradd -r -u 900 -m -c "ckan account" -d $CKAN_HOME -s /bin/false ckan

# Setup virtual environment for CKAN
RUN mkdir -p $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH && \
    virtualenv $CKAN_VENV && \
    ln -s $CKAN_VENV/bin/pip /usr/local/bin/ckan-pip &&\
    ln -s $CKAN_VENV/bin/paster /usr/local/bin/ckan-paster

# Setup CKAN
ADD . $CKAN_VENV/src/ckan/
RUN ckan-pip install -U pip && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirement-setuptools.txt && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirements.txt && \
    ckan-pip install -e $CKAN_VENV/src/ckan/ && \
    ln -s $CKAN_VENV/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini && \
    cp -v $CKAN_VENV/src/ckan/contrib/docker/ckan-entrypoint.sh /ckan-entrypoint.sh && \
    chmod +x /ckan-entrypoint.sh && \
    chown -R ckan:ckan $CKAN_HOME $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH

RUN pip install -e git+https://github.com/SFB-ELAINE/ckanext-disablepwreset.git@37074f72078c37bc3e21fa2bb36ee40fdcfb6bbd#egg=ckanext_disablepwreset
RUN pip install -e git+https://github.com/hayley-leblanc/ckanext-pdfview.git@31-fix-flask-exception#egg=ckanext_pdfview
RUN pip install -e git+https://github.com/SFB-ELAINE/ckanext-privatedatasets.git@elaine-new-version#egg=ckanext_privatedatasets
RUN pip install -e git+https://github.com/TIBHannover/ckanext-videoviewer.git#egg=ckanext_videoviewer
RUN pip install -e git+https://github.com/SFB-ELAINE/ckanext-papaya.git#egg=ckanext-papaya
RUN pip install -e git+https://github.com/SFB-ELAINE/ckanext-vtkjs#egg=ckanext-vtkjs
RUN pip install -e git+https://github.com/SFB-ELAINE/ckanext-elaine_theme.git#egg=ckanext_elaine_theme

# Install prerequisites for LDAP plugin
RUN apt-get -q -y update \
    && apt-get -q -y install \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*
RUN cd $CKAN_VENV/src/ \
    && git clone --single-branch -b ckan-upgrade-2.8.0a https://github.com/NaturalHistoryMuseum/ckanext-ldap.git \
    && cd ckanext-ldap \
    && git log | head\
    && pip install -r requirements.txt \
    && pip install -e .

ENTRYPOINT ["/ckan-entrypoint.sh"]

USER ckan
EXPOSE 5000

CMD ["ckan-paster","serve","/etc/ckan/production.ini"]
