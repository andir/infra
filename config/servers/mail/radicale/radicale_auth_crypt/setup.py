#!/usr/bin/env python3

from setuptools import setup

setup(
    name="radicale-auth-crypt",
    version="0.1",
    description="CRYPT Authentication Plugin for Radicale 2",
    author="Andreas Rammhold",
    license="GNU GPL v3",
#    install_requires=["radicale >= 2.0"], # left out to avoid dependency cycle
    packages=["radicale_auth_crypt"])
