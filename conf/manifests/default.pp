# This manifest installs the supersmart pipeline, 
# for more information http://www.supersmart-project.org

# update the $PATH environment variable for the Exec tasks.
Exec {
	path => [ 
		"/usr/local/sbin", 
		"/usr/local/bin",
		"/usr/sbin",
		"/usr/bin",
		"/sbin",
		"/bin",
	]
}

# install packages. most likely this is done with yum.
package {
	"mysql-server":             ensure => installed;
	"mysql":                    ensure => installed;
	"ncbi-blast+.x86_64":       ensure => installed;
	"wget":                     ensure => installed;
	"tar":                      ensure => installed;
	"perl-DBI":                 ensure => installed;
	"perl-DBD-MySQL":           ensure => installed;
	"perl-DBIx-Class":          ensure => installed;
	"perl-Template-Toolkit":    ensure => installed;
	"perl-JSON":                ensure => installed;
	"perl-Moose":               ensure => installed;
	"perl-XML-Twig":            ensure => installed;
	"perl-HTML-Parser":         ensure => installed;
	"perl-Config-Tiny":         ensure => installed;
	"perl-bioperl":             ensure => installed;
	"git":                      ensure => installed;
	"zlib-devel":               ensure => installed;
	"autoconf":                 ensure => installed;
	"automake":                 ensure => installed;
	"libtool":                  ensure => installed;
	"gcc-c++":                  ensure => installed;	
	"curl":                     ensure => installed;
	"gzip":                     ensure => installed;
}

# set up the mysql daemon process
service { 
	"mysqld":
		enable  => true,
		ensure  => running,
		require => Package["mysql-server"],
}

# create links for executables and data directories
file {
	"muscle_link":
		path    => "/usr/local/bin/muscle",
		ensure  => link,
		target  => "/usr/local/src/muscle3.8.31_i86linux64",
		require => Exec["unzip_muscle"];
	"consense_link":
		path    => "/usr/local/bin/consense",
		ensure  => link,
		target  => "/usr/local/src/phylip-3.695/src/consense",
		require => Exec["make_phylip"];
	"examl_link":
		path    => "/usr/local/bin/examl",
		ensure  => link,
		target  => "/usr/local/src/ExaML/examl/examl",
		require => Exec["compile_examl"];
	"parser_link":
		path    => "/usr/local/bin/parser",
		ensure  => link,
		target  => "/usr/local/src/ExaML/parser/parser",
		require => Exec["compile_parser"];
	"treepl_link":
		path    => "/usr/local/bin/treePL",
		ensure  => link,
		target  => "/usr/local/src/treePL/src/treePL",
		require => Exec["compile_treepl"];
	"data_dir":
		path    => "/usr/share/supersmart",
		ensure  => directory;
	"inparanoid_dir":
		path    => "/usr/share/supersmart/inparanoid",
		ensure  => directory;
		
}

# command line tasks
exec {

	# download data	
	"dl_phylota_dump":
		command => "curl http://phylota.net/pb/Download/184/pb.bu.rel184.4.10.2012.parta{a,b,c,d,e} > pb.bu.rel184.4.10.2012.gz",
		cwd     => "/usr/share/supersmart",
		creates => "/usr/share/supersmart/pb.bu.rel184.4.10.2012.gz",
		require => [ File[ 'data_dir' ], Package[ 'curl' ] ];
	"dl_inparanoid_seq":
		command => "curl http://inparanoid.sbc.su.se/download/current/sequences/processed/FASTA -o inparanoid.fa",
		cwd     => "/usr/share/supersmart",
		creates => "/usr/share/supersmart/inparanoid.fa",
		require => [ File[ 'data_dir' ], Package[ 'curl' ] ];
	"dl_inparanoid_tables":
		command => "wget http://inparanoid.sbc.su.se/download/old_versions/data_7.0/sqltables.tgz",
		cwd     => "/usr/share/supersmart/inparanoid",
		creates => "/usr/share/supersmart/inparanoid/sqltables.tgz",
		require => [ File[ 'inparanoid_dir' ], Package[ 'wget' ] ];
	
	# make phylota db
	"phylota_db":
		command => "mysql -e 'create database phylota;'",
		creates => "/var/lib/mysql/phylota",
		require => [ Package[ 'mysql', 'mysql-server' ], Service[ 'mysqld' ] ];		
	"inparanoid_sql":
		command => "mysql phylota < /usr/local/src/supersmart/sql/inparanoid.sql",
		creates => "/var/lib/mysql/phylota/inparanoid.frm",
		require => Exec['phylota_db','clone_supersmart'];
	"phylota_load":
		command => "gunzip -c /usr/share/supersmart/pb.bu.rel184.4.10.2012.gz | mysql phylota",
		creates => "/var/lib/mysql/phylota/seq.frm",
		require => Exec['phylota_db','dl_phylota_dump'];
	"phylota_patch":
		command => "mysql phylota -e 'alter table ci_gi_184 add index(ti_of_gi);' -v > /usr/local/src/supersmart/sql/ci_gi_184.log",
		creates => "/usr/local/src/supersmart/sql/ci_gi_184.log",
		require => Exec['phylota_load'];		

	# make inparanoid blast db
	"inparanoid_formatdb":
		command => "makeblastdb -in inparanoid.fa -logfile inparanoid-blast.log -dbtype prot -parse_seqids",
		cwd     => "/usr/share/supersmart",
		creates => "/usr/share/supersmart/inparanoid-blast.log",
		timeout => 0,		
		require => [ Exec[ 'dl_inparanoid_seq' ], Package[ 'ncbi-blast+.x86_64' ] ];		

	# make profile.d files
	"make_supersmart_sh":
		command => "echo 'export LD_LIBRARY_PATH=/usr/lib' > supersmart.sh",
		cwd     => "/etc/profile.d",
		creates => "/etc/profile.d/supersmart.sh";
	"make_supersmart_csh":
		command => "echo 'setenv LD_LIBRARY_PATH /usr/lib' > supersmart.csh",
		cwd     => "/etc/profile.d",
		creates => "/etc/profile.d/supersmart.csh";

	# install muscle multiple sequence alignment
	"download_muscle":
		command => "wget http://www.drive5.com/muscle/downloads3.8.31/muscle3.8.31_i86linux64.tar.gz",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/muscle3.8.31_i86linux64.tar.gz",
		require => Package[ 'wget', 'tar' ];
	"unzip_muscle":
		command => "tar -xzvf /usr/local/src/muscle3.8.31_i86linux64.tar.gz",
		cwd     => "/usr/local/src",		
		creates => "/usr/local/src/muscle3.8.31_i86linux64",
		require => Exec["download_muscle"];
		
	# install perl package Parallel::MPI::Simple
	"download_parallel_mpi_simple":
		command => "wget http://search.cpan.org/CPAN/authors/id/A/AJ/AJGOUGH/Parallel-MPI-Simple-0.10.tar.gz",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/Parallel-MPI-Simple-0.10.tar.gz",
		require => Package[ 'wget', 'tar' ];		
	"unzip_parallel_mpi_simple":
		command => "tar -xzvf /usr/local/src/Parallel-MPI-Simple-0.10.tar.gz",
		cwd     => "/usr/local/src",		
		creates => "/usr/local/src/Parallel-MPI-Simple-0.10/Makefile.PL",
		require => Exec["download_parallel_mpi_simple"];
	"make_makefile_parallel_mpi_simple":
		command => "perl Makefile.PL CCFLAGS='-I/usr/include' LDFLAGS='-L/usr/lib/ -lmpi' CC=mpicc LD=mpicc",
		cwd     => "/usr/local/src/Parallel-MPI-Simple-0.10/",
		creates => "/usr/local/src/Parallel-MPI-Simple-0.10/Makefile",
		require => Exec["unzip_parallel_mpi_simple","install_openmpi"];
	"make_install_parallel_mpi_simple":
		command => "make install LD_LIBRARY_PATH=/usr/lib",
		cwd     => "/usr/local/src/Parallel-MPI-Simple-0.10/",		
		creates => "/usr/local/src/Parallel-MPI-Simple-0.10/Simple.so",
		require => Exec["make_makefile_parallel_mpi_simple"];	
		
	# install openmpi
	"download_openmpi":
		command => "wget http://www.open-mpi.org/software/ompi/v1.6/downloads/openmpi-1.6.5.tar.gz",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/openmpi-1.6.5.tar.gz",
		require => Package[ 'wget', 'tar' ];
	"unzip_openmpi":
		command => "tar -xvzf openmpi-1.6.5.tar.gz",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/openmpi-1.6.5",
		require => Exec['download_openmpi'];
	"install_openmpi":
		command => "/usr/local/src/openmpi-1.6.5/configure --prefix=/usr --disable-dlopen && make install",
		creates => "/usr/bin/mpicc",
		cwd     => "/usr/local/src/openmpi-1.6.5",
		timeout => 0,
		require => Exec['unzip_openmpi'];
	
	# install phylip
	"download_phylip":
		command => "wget http://evolution.gs.washington.edu/phylip/download/phylip-3.695.tar.gz",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/phylip-3.695.tar.gz",
		require => Package[ 'wget', 'tar' ];
	"unzip_phylip":
		command => "tar -xzvf /usr/local/src/phylip-3.695.tar.gz",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/phylip-3.695/src/Makefile.unx",
		require => Exec["download_phylip"];
	"make_phylip":
		command => "make -f Makefile.unx consense",
		cwd     => "/usr/local/src/phylip-3.695/src/",
		creates => "/usr/local/src/phylip-3.695/src/consense",
		require => Exec["unzip_phylip"];
	
	# install examl & parser
	"clone_examl":
		command => "git clone https://github.com/stamatak/ExaML.git",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/ExaML/",
		require => Package[ 'git', 'zlib-devel' ];
	"compile_examl":
		command => "make -f Makefile.SSE3.gcc LD_LIBRARY_PATH=/usr/lib",
		cwd     => "/usr/local/src/ExaML/examl",
		creates => "/usr/local/src/ExaML/examl/examl",
		require => Exec["clone_examl","install_openmpi"];
	"compile_parser":
		command => "make -f Makefile.SSE3.gcc",
		cwd     => "/usr/local/src/ExaML/parser",
		creates => "/usr/local/src/ExaML/parser/parser",
		require => Exec["clone_examl","install_openmpi"];
		
	# install supersmart
	"clone_supersmart":
		command => "git clone https://github.com/naturalis/supersmart.git",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/supersmart",
		require => Package[ 'git' ];
	
	# install treePL
	"clone_treepl":
		command => "git clone https://github.com/blackrim/treePL.git",
		cwd     => "/usr/local/src",
		creates => "/usr/local/src/treePL",
		require => Package[ 'git', 'autoconf', 'automake', 'libtool', 'gcc-c++', 'tar' ];
	"unzip_adolc":
		command => "tar -xvzf adol-c_git_saved.tar.gz",
		cwd     => "/usr/local/src/treePL/deps",
		creates => "/usr/local/src/treePL/deps/adol-c",
		require => Exec["clone_treepl","install_openmpi"];
	"autoreconf_adolc":
		command => "autoreconf -fi",
		cwd     => "/usr/local/src/treePL/deps/adol-c",
		creates => "/usr/local/src/treePL/deps/adol-c/configure",
		require => Exec["unzip_adolc"];
	"install_adolc":
		command => "/usr/local/src/treePL/deps/adol-c/configure --prefix=/usr --with-openmp-flag=-fopenmp && make install",
		cwd     => "/usr/local/src/treePL/deps/adol-c",
		creates => "/usr/lib64/libadolc.so",
		require => Exec["autoreconf_adolc"];
	"unzip_nlopt":
		command => "tar -xzvf nlopt-2.2.4.tar.gz",
		cwd     => "/usr/local/src/treePL/deps",
		creates => "/usr/local/src/treePL/deps/nlopt-2.2.4",
		require => Exec["clone_treepl","install_openmpi"];
	"install_nlopt":
		command => "/usr/local/src/treePL/deps/nlopt-2.2.4/configure && make install",
		cwd		=> "/usr/local/src/treePL/deps/nlopt-2.2.4",
		creates => "/usr/local/include/nlopt.h",
		require => Exec["unzip_nlopt"];
	"compile_treepl":
		command => "/usr/local/src/treePL/src/configure && make",
		cwd     => "/usr/local/src/treePL/src",
		creates => "/usr/local/src/treePL/src/treePL",
		require => Exec["install_adolc","install_nlopt"];		
}