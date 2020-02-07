Installation
############

Install OpenStudio and PAT
==========================

Download the latest stable software version of OpenStudio (2.9.1) from the `OpenStudio developer website <https://www.openstudio.net/developers>`_.
This is necessary because the latest critical changes to run ResStock projects are only available in the latest version.
Do a default install including Parametric Analysis Tool (PAT). 

Open the Parametric Analysis Tool (PAT). You may be asked if you would like to allow openstudio to allow connections. Select "Allow".

.. image:: ../images/tutorial/allow_connections.png

Download the ResStock repository
================================

Go to the `releases page on GitHub <https://github.com/NREL/OpenStudio-BuildStock/releases>`_, select a release, and either ``git clone`` or download a zip of the repository. The ``master`` branch is under active development, so we recommend using the latest `release <https://github.com/NREL/OpenStudio-BuildStock/releases>`_ for production runs.

Developer instructions
======================

If you will be developing residential measures and testing residential building models, see the :ref:`advanced_tutorial`. If you are a developer, make sure that you have checked out the ``master`` branch of the repository.
