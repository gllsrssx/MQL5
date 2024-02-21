#include <..\Experts\newsBT\newsDownloader.mqh>;

input string landCode; // country code
input bool allCC; // all countries

void OnInit(){
   if(allCC){
      downloadNews();
   }else{
      downloadCountryNews(landCode);
   }
}