#include <..\Experts\newsBT\newsDownloader.mqh>;

input string landCode; // country code
input bool allCC=true; // all countries

void OnInit(){
   if(allCC){
      downloadNews();
   }else{
      downloadCountryNews(landCode);
   }
}