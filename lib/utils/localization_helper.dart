import 'package:flutter/widgets.dart';
import 'package:plant_diagnosis_app/l10n/app_localizations.dart';

class LocalizationHelper {
  static Map<String, String> getDiseaseMap(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return {
      // 🍏 Apple
      "scab": loc.scab,
      "scab_treatment": loc.scab_treatment,
      "black_rot": loc.black_rot,
      "black_rot_treatment": loc.black_rot_treatment,
      "cedar_rust": loc.cedar_rust,
      "cedar_rust_treatment": loc.cedar_rust_treatment,
      "healthy": loc.healthy,

      
     

      // 🍒 Cherry
      "powdery_mildew": loc.powdery_mildew,
      "powdery_mildew_treatment": loc.powdery_mildew_treatment,
     
      // 🌽 Corn (maize)
      "gray_leaf_spot": loc.gray_leaf_spot,
      "gray_leaf_spot_treatment": loc.gray_leaf_spot_treatment,
      "common_rust": loc.common_rust,
      "common_rust_treatment": loc.common_rust_treatment,
      "northern_Leaf_Blight":loc.northern_leaf_blight,
      "northern_Leaf_Blight_treatment": loc.northern_leaf_blight_treatment,
     

      // 🍇 Grape
      "black_rot": loc.black_rot,
      "black_rot_treatment": loc.black_rot_treatment,
      "Esca": loc.esca,
      "Esca_treatment": loc.esca_treatment,
      "Leaf_blight": loc.leaf_blight,
      "Leaf_blight_treatment": loc.leaf_blight_treatment,
      

      // 🍑 Peach
      "bacrerial_spot": loc.bacrerial_spot,
      "bacrerial_spot_treatment": loc.bacrerial_spot_treatment,
     

      // 🥔 Potato
      "early_blight": loc.early_blight,
      "early_blight_treatment": loc.early_blight_treatment,
      "late_blight": loc.late_blight,
      "late_blight_treatment": loc.late_blight_treatment,
      

    
     
  

      // 🍅 Tomato

      "Leaf_Mold": loc.leaf_mold,
      "Leaf_Mold_treatment": loc.leaf_mold_treatment,
      "Tomato___Septoria_leaf_spot": loc.tomato_septoria_leaf_spot,
      "Tomato___Septoria_leaf_spot_treatment": loc.tomato_septoria_leaf_spot_treatment,
      "spider_mites": loc.spider_mites,
      "spider_mites_treatment": loc.spider_mites_treatment,
      "target_Spot": loc.target_spot,
      "target_Spot_treatment": loc.target_spot_treatment,
      "yellow_Leaf_Curl_Virus": loc.yellow_leaf_curl,
      "yellow_Leaf_Curl_Virus_treatment": loc.yellow_leaf_curl_treatment,
      "mosaic_virus": loc.mosaic_virus,
      "mosaic_virus_treatment": loc.mosaic_virus_treatment,
     

     
     

      // 🍊 Orange
      "Orange___Haunglongbing_(Citrus_greening)": loc.orange_hlb,
      "Orange___Haunglongbing_(Citrus_greening)_treatment": loc.orange_hlb_treatment,

      // 🍓 Strawberry
      "Strawberry___Leaf_scorch": loc.strawberry_leaf_scorch,
      "Strawberry___Leaf_scorch_treatment": loc.strawberry_leaf_scorch_treatment,
      
	 // "algal": loc.algal,
     // "algal_treatment": loc.algal_treatment,
  
     // "anthracnose": loc.anthracnose,
     // "anthracnose_treatment": loc.anthracnose_treatment,
  
   
     // "brown_blight": loc.brown_blight,
     // "brown_blight_treatment": loc.brown_blight_treatment,
  
     // "gray_blight": loc.gray blight,
     // "gray_blight_treatment": loc.gray_blight_treatment,
  


    };
  }
}
