let pkgs = import (builtins.fetchTarball {
      url = "https://github.com/costrouc/nixpkgs/archive/907fe9c6eb7686418bea60c3745bb0db95b66baa.tar.gz";
      sha256 = "0rxffhfcdizc6nydaj9xmafsfhfd91yiwpal76c3afk577kdg9kr";
    }) { };

    pythonPackages = pkgs.python3Packages;

    flask-0_12_4 = pythonPackages.flask.overrideAttrs(super: rec {
      name = "flask-0.12.4";

      src = pythonPackages.fetchPypi {
        pname = "Flask";
        version = "0.12.4";
        sha256 = "1pamldmw2y7gd5s41rrnwaiqlji4065byfmw8arb926kyqv278if";
      };

      postInstall = ''
        ${pythonPackages.nixpkgs-pytools}/bin/python-rewrite-imports --path $out/${pythonPackages.python.sitePackages}/ \
          --replace flask flask_0_12_4_1pamldmw2y7g

        # remove btye compiled files
        find $out/${pythonPackages.python.sitePackages} -type f -name '*.pyc' -delete

        # rename dist
        mv $out/${pythonPackages.python.sitePackages}/Flask-0.12.4.dist-info $out/${pythonPackages.python.sitePackages}/flask_0_12_4_1pamldmw2y7g-0.12.4.dist-info
      '';
   });

   bizbaz = pythonPackages.buildPythonPackage {
     pname = "bizbaz";
     version = "0.1";

     src = ./bizbaz;

     propagatedBuildInputs = [ flask-0_12_4 ];

     postPatch = ''
       substituteInPlace setup.py \
          --replace "flask==0.12.4" "flask_0_12_4_1pamldmw2y7g"

       ${pythonPackages.nixpkgs-pytools}/bin/python-rewrite-imports --path $PWD \
          --replace flask flask_0_12_4_1pamldmw2y7g
     '';
   };

   foobar = pythonPackages.buildPythonPackage {
     pname = "foobar";
     version = "0.1";

     src = ./foobar;

     propagatedBuildInputs = [ pythonPackages.flask ];
   };
in pkgs.mkShell {
  buildInputs = [ bizbaz foobar ];
}
