from setuptools import setup, find_packages

setup_args = {
    'name': 'opendisc',
    'version': '0.1',
    'description': 'Open Discovery program analysis for Python',
    'include_package_data': True,
    'packages': find_packages(),
    'zip_safe': False,
    'author': 'Evan Patterson',
    'author_email': 'evan.patterson@ibm.com',
    'install_requires': [
        # core package
        'pathlib2',
        'six',
        'traitlets',
        'jsonpickle',
        'networkx==1.11',
        'cachetools>=2.0.0',
        'blitzdb>=0.3',
        'CouchDB>1.1',
        'sqlalchemy',
        'ipykernel>=4.3.0',
    ],
    'tests_require': [
        # integration tests
        'pandas',
        'scipy',
        'sklearn',
        'statsmodels',
    ],
}

setup(**setup_args)
