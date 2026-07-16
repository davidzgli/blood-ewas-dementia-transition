#' Assign biological function categories to GO term descriptions
#'
#' Uses priority-ordered keyword matching to classify GO term descriptions
#' into one of 22 biological function categories.
#'
#' @param description A character vector of GO term descriptions
#'
#' @return A character vector of category assignments (NA for unmatched terms)
#' @export
#'
#' @examples
#' assign_biofunc_category("regulation of synaptic vesicle fusion to presynaptic active zone membrane")
#' assign_biofunc_category(c("fear response", "wound healing", "axonogenesis"))

assign_biofunc_category <- function(description) {
  desc <- tolower(description)

  dplyr::case_when(
    # 1. Synaptic Vesicle Control
    stringr::str_detect(desc, "synaptic vesicle|vesicle fusion") ~
      "Synaptic Vesicle Control",

    # 2. Regulatory Mechanisms
    stringr::str_detect(desc, "mirna transcription") ~
      "Regulatory Mechanisms",

    # 3. Behavioral Response
    stringr::str_detect(desc, "fear response") ~
      "Behavioral Response",

    # 4. Tissue Response (exclude vascular wound healing)
    stringr::str_detect(desc, "wound healing") &
      !stringr::str_detect(desc, "vascular") ~
      "Tissue Response",

    # 5. Cellular Homeostasis
    stringr::str_detect(desc, "body fluid levels") ~
      "Cellular Homeostasis",

    # 6. Hypoxia Response
    stringr::str_detect(desc, "hypoxia|oxygen levels") ~
      "Hypoxia Response",

    # 7. Extracellular Matrix Organization
    stringr::str_detect(desc, "collagen|extracellular matrix|extracellular structure|encapsulating structure") ~
      "Extracellular Matrix Organization",

    # 8. Synaptic Function and Organization
    stringr::str_detect(desc, "synap|glutamate receptor") ~
      "Synaptic Function and Organization",

    # 9. Glial Cell Regulation
    stringr::str_detect(desc, "glial|astrocyte|schwann|gliogenesis") ~
      "Glial Cell Regulation",

    # 10. Ion Transport and Regulation
    stringr::str_detect(
      desc,
      paste0(
        "\\bcation\\b|potassium|calcium ion|monoatomic|voltage-gated|",
        "ion channel|ion transmembrane|membrane.*potential|",
        "transporter activity|transmembrane transport|depolariz"
      )
    ) &
      !stringr::str_detect(desc, "exocytosis|metal ion") ~
      "Ion Transport and Regulation",

    # 11. Immune Response
    stringr::str_detect(
      desc,
      paste0(
        "leukocyte|lymphocyte|\\bt cell|\\bb cell|myeloid|hemopoiesis|",
        "interleukin|mhc|antigen|thymic|erythrocyte|mononuclear"
      )
    ) ~
      "Immune Response",

    # 12. Neural Development and Regulation
    stringr::str_detect(
      desc,
      paste0(
        "neuron|neural|axon|dendrit|cerebr|cerebell|spinal cord|",
        "forebrain|hindbrain|telencephalon|diencephalon|nervous system|",
        "limbic|pallium|metencephalon|visual system|sensory system|",
        "oligodendrocyte|neuroblast|neuroepithelial|olfactory bulb|",
        "myelin|neurogenesis"
      )
    ) ~
      "Neural Development and Regulation",

    # 13. Vascular Development (exclude terms with cell migration)
    stringr::str_detect(
      desc,
      paste0(
        "cardiac|heart|valve|ventricle|septum|angiogenesis|blood vessel|",
        "artery|arterial|endothelial|endocardial|cardiocyte|outflow tract|",
        "blood circulat|blood pressure|vascul"
      )
    ) &
      !stringr::str_detect(desc, "cell migration") ~
      "Vascular Development",

    # 14. Hormone Signaling
    stringr::str_detect(
      desc,
      paste0(
        "hormone|steroid|corticosteroid|glucocorticoid|retinoic acid|",
        "endocrine|nuclear receptor|intracellular receptor signaling"
      )
    ) ~
      "Hormone Signaling",

    # 15. Gene Regulation
    stringr::str_detect(
      desc,
      paste0(
        "transcription regulatory region|dna binding|snrna metabolic|",
        "mirna metabolic|transcription elongation"
      )
    ) ~
      "Gene Regulation",

    # 16. Cell Cycle Regulation
    stringr::str_detect(desc, "cell cycle|g1/s") ~
      "Cell Cycle Regulation",

    # 17. Cell Migration and Organization
    stringr::str_detect(
      desc,
      paste0(
        "cell migration|cell-substrate junction|cell junction|adhesion|",
        "lamellipodium|actomyosin|stress fiber|locomotion|cell projection|",
        "epithelium migration|epithelial cell migration"
      )
    ) ~
      "Cell Migration and Organization",

    # 18. Cellular Metabolism
    stringr::str_detect(
      desc,
      paste0(
        "amyloid|proteoglycan|polysaccharide|ganglioside|viral protein|",
        "glucose|energy homeostasis|carbohydrate homeostasis|",
        "redox homeostasis|nutrient|hexose|ketone|protein catabolic"
      )
    ) ~
      "Cellular Metabolism",

    # 19. Cellular Transport
    stringr::str_detect(
      desc,
      paste0(
        "exocytosis|exocytic|endosomal|nuclear transport|nucleocytoplasmic|",
        "protein localization|peptide secretion|peptide transport|",
        "intracellular.*transport|sterol transport|vesicle-mediated transport|",
        "cytosolic transport|protein transport|regulation of transport"
      )
    ) ~
      "Cellular Transport",

    # 20. Cellular Signaling
    stringr::str_detect(
      desc,
      paste0(
        "wnt|mapk|kinase|gtpase|notch|ras protein|rho protein|smad|bmp|",
        "phosphorylat|phosphatidylinositol|integrin-mediated|",
        "transferase activity|growth factor|apoptotic signaling|",
        "signal transduction|signal.*release|signaling pathway|",
        "response to fatty acid|response to metal ion|",
        "cellular response to peptide|rhythmic process|protein sumoylation"
      )
    ) ~
      "Cellular Signaling",

    # 21. Cellular Organization
    stringr::str_detect(
      desc,
      "cell polarity|maintenance of location|stress granule|cellular component biogenesis"
    ) ~
      "Cellular Organization",

    # 22. Development and Differentiation (broad catch-all)
    stringr::str_detect(
      desc,
      paste0(
        "develop|differentiat|morphogen|growth|proliferat|ossificat|specif|",
        "gastrulat|germ layer|mesenchym|endoderm|remodel|molting|segment|",
        "epiderm|hair cycle|formation|resorption|muscle|anatomical|",
        "regionalization|maintenance|regenerat|odontogenesis"
      )
    ) ~
      "Development and Differentiation",

    # Fallback
    TRUE ~ NA_character_
  )
}
