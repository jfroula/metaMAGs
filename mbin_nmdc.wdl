workflow nmdc_mags {
    String? outdir
    String  proj_name
    File    contig_file
    File    sam_file
    File    gff_file
    #String  container = "microbiomedata/nmdc_mbin:0.1.2"
    String  container = "microbiomedata/nmdc_mbinsha@256:0a7bfa50719f5b4b173065fc23c28ec6e2eeed1ac794f605903776e06850c141"
    File?   map_file
    File?   domain_file
    String? scratch_dir
    Int     cpu=32
    Int     pplacer_cpu=1

    String gtdbtk_database="/refdata/GTDBTK_DB"

    call mbin_nmdc{
         input:  name=proj_name,
                 fasta=contig_file,
                 sam=sam_file,
                 gff=gff_file,
                 map=map_file,
                 domain=domain_file,
		 cpu=cpu,
                 pplacer_cpu=pplacer_cpu,
		 scratch_dir=scratch_dir,
                 database=gtdbtk_database,
	         container=container
    }

    if (defined(outdir)){
        call make_output {
           	input: short=mbin_nmdc.short,
                   low=mbin_nmdc.low,
                   unbinned=mbin_nmdc.unbinned,
                   hqmq_bin_fasta_files=mbin_nmdc.hqmq_bin_fasta_files,
                   bin_fasta_files=mbin_nmdc.bin_fasta_files,
        	   gtdbtk_bac_summary=mbin_nmdc.bacsum,
        	   gtdbtk_ar_summary=mbin_nmdc.arcsum,
                   outdir=outdir
        }
    }

    output {
	File? final_hqmq_bins_zip = make_output.hqmq_bin_fasta_zip
	File? metabat_bins_zip = make_output.metabat_bin_fasta_zip
	File? final_checkm = make_output.checkm_output
	File? final_gtdbtk_bac_summary = make_output.bac_summary
	File? final_gtdbtk_ar_summary = make_output.ar_summary
	File? final_tooShort_fa = make_output.tooShort_fa
	File? final_lowDepth_fa = make_output.lowDepth_fa
	File? final_unbinned_fa = make_output.unbinned_fa
        File short = mbin_nmdc.short
        File low = mbin_nmdc.low
        File unbinned = mbin_nmdc.unbinned
        File? checkm = mbin_nmdc.checkm
        File stats_json = mbin_nmdc.stats_json
	Array[File] hqmq_bin_fasta_files = mbin_nmdc.hqmq_bin_fasta_files
	Array[File] bin_fasta_files = mbin_nmdc.bin_fasta_files
    }
    parameter_meta {
	cpu: "number of CPUs"
        pplacer_cpu: "number of threads used by pplacer"
	outdir: "the final output directory path"
	scratch_dir: "use --scratch_dir for gtdbtk disk swap to reduce memory usage but longer runtime"
	proj_name: "project name"
	contig_file: "input assembled contig fasta file"
	sam_file: "Sam/Bam file from reads mapping back to contigs. [sam.gz or bam]"
	gff_file: "contigs functional annotation result in gff format"
	map_file: "text file which containing mapping of headers between SAM and FNA (ID in SAM/FNA ID in GFF)"
	database: "GTDBTK_DB database directory path"
	final_hqmq_bins: "high quality and medium quality bin fasta output"
	metabat_bins: "initial metabat bining result fasta output"
	final_checkm: "metabat bin checkm result"
	final_gtdbtk_bac_summary: "gtdbtk bacterial assignment result summary table"
	final_gtdbtk_ar_summary: "gtdbtk archaea assignment result summary table"
	final_tooShort_fa: "tooShort (< 3kb) filtered contigs fasta file by metaBat2"
	final_lowDepth_fa: "lowDepth (mean cov <1 )  filtered contigs fasta file by metabat2"
	final_unbinned_fa: "unbinned fasta file from metabat2"
    }
    meta {
        author: "Chienchi Lo, B10, LANL"
        email: "chienchi@lanl.gov"
        version: "1.0.1"
    }
}

task mbin_nmdc {
	String name
	File fasta
	File sam
	File gff
	File? map
	File? domain
        String database
	Int cpu
        Int pplacer_cpu
	String? scratch_dir
        String container
	String filename_stat="checkm_qa.out"
	runtime {
                docker: container
		memory: "120G"
		cpu: cpu
                time: "00:20:00"
 	}

     command {
	set -eo pipefail
	export TMPDIR=/tmp
	export GTDBTK_DATA_PATH=${database}
	mbin_nmdc.py ${"--map " + map} ${"--domain " + domain} ${"--scratch_dir " + scratch_dir} --pplacer_cpu ${pplacer_cpu} --cpu ${cpu} ${name} ${fasta} ${sam} ${gff}
	mbin_stats.py "$PWD"
     }

     output {
	File runScript = "script"
	File? stat = filename_stat
        File short = "bins.tooShort.fa"
        File low = "bins.lowDepth.fa"
        File unbinned = "bins.unbinned.fa"
        File? checkm = "checkm_qa.out"
        File? bacsum = "gtdbtk.bac120.summary.tsv"
        File? arcsum = "gtdbtk.ar122.summary.tsv"
        File stats_json = "MAGs_stats.json"
	Array[File] hqmq_bin_fasta_files = glob("hqmq-metabat-bins/*fa")
	Array[File] bin_fasta_files = glob("metabat-bins/*fa")
     }
}

task make_output{
        File short
        File low
        File unbinned
        Array[File] hqmq_bin_fasta_files
        Array[File] bin_fasta_files
	File? gtdbtk_bac_summary
	File? gtdbtk_ar_summary
 	String? outdir
        String container="scanon/nmdc-meta:v0.0.2"

 	command{
                zip hqmq-metabat-bins.zip ${sep=" " hqmq_bin_fasta_files}
                zip metabat-bins.zip ${sep=" " bin_fasta_files}
                if [ -n ${outdir} ] ; then
                    mkdir -p ${outdir}
                    cp ${short} ${low} ${unbinned} \
                       ${gtdbtk_bac_summary} ${gtdbtk_ar_summary} \
                       ${outdir}
                    # These may not exist
                    [ -e hqmq-metabat-bins.zip ] && cp hqmq-metabat-bins.zip ${outdir}
                    [ -e metabat-bins.zip ] && cp metabat-bins.zip ${outdir}
                    chmod 764 -R ${outdir}
                fi
 	}
	output {
		File checkm_output = "${outdir}/checkm_qa.out"
		File bac_summary = "${outdir}/gtdbtk.bac120.summary.tsv"
		File ar_summary = "${outdir}/gtdbtk.ar122.summary.tsv"
		File unbinned_fa = "${outdir}/bins.unbinned.fa"
		File tooShort_fa = "${outdir}/bins.tooShort.fa"
		File lowDepth_fa = "${outdir}/bins.lowDepth.fa"
		File hqmq_bin_fasta_zip = "${outdir}/hqmq-metabat-bins.zip"
		File metabat_bin_fasta_zip = "${outdir}/metabat-bins.zip"
		File? hqmq_bin_zip = "hqmq-metabat-bins.zip"
		File? metabat_bin_zip = "metabat-bins.zip"
	}
	runtime {
            docker: container
            memory: "1G"
            cpu:  1
            time: "00:20:00"
        }
}

