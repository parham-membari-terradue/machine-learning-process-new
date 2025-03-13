FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive
ENV APP_ENV=make_inference

SHELL ["/bin/bash", "-c"]
RUN apt-get update -yq                                                                                                      && \
    apt-get install -y ca-certificates ttf-dejavu file wget bash bzip2 sudo                                                 && \
    apt-get clean autoremove --yes                                                                                     && \
    rm -rf /var/lib/{apt,dpkg,cache,log}


ARG USERNAME=linus
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME                                                                                      && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME                                                                    && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME                                                     && \
    chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME
RUN echo $PATH
ENV BASH_ENV=~/.bashrc
ENV MAMBA_ROOT_PREFIX=/home/$USERNAME/conda
ENV PATH=$PATH:/home/$USERNAME/conda/envs/$APP_ENV/bin:/home/$USERNAME/conda/envs/$APP_ENV/snap/bin
RUN echo $PATH
COPY --from=docker.io/mambaorg/micromamba:alpine /bin/micromamba /bin/micromamba
RUN micromamba shell init -s zsh -p ~/micromamba

COPY --chown=$USERNAME:$USER_GID . /tmp

RUN micromamba create -f /tmp/environment.yml                                                                               && \
    cd /tmp                                                                                                                 && \
    $MAMBA_ROOT_PREFIX/envs/$APP_ENV/bin/python setup.py install
    #sudo rm -fr $MAMBA_ROOT_PREFIX/pkgs
    #sudo rm -fr /tmp/*

# Activate environment
ENV CONDA_DEFAULT_ENV=$APP_ENV
ENV ENV_NAME=$APP_ENV
ENV CONDA_PROMPT_MODIFIER=($APP_ENV)
