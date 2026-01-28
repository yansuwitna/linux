#include <Trade\Trade.mqh>
CTrade trade;

// Input parameter
input ENUM_TIMEFRAMES TimeframeH1 = PERIOD_H1;
input ENUM_TIMEFRAMES TimeframeM5 = PERIOD_M5;
input double TakeProfitPoints = 50;
input double StopLossPoints = 200;
input double LotSize = 0.01;
input int StartHour = 9;      // Jam mulai trading (24 jam format)
input int EndHour = 18;        // Jam akhir trading

// Fungsi untuk menghitung garis tengah
double GetMiddle(double high, double low) {
   return (high + low) / 2.0;
}

// Fungsi untuk memeriksa apakah sudah ada posisi terbuka di simbol ini
bool IsPositionOpen(string symbol) {
   for (int i = 0; i < PositionsTotal(); i++) {
      if (PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == symbol)
         return true;
   }
   return false;
}

void OnTick() {
  
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt); // Ubah waktu server ke struktur
   
   int currentHour = dt.hour;
   
   string info = "";

   // Batasi waktu trading
   if (currentHour < StartHour || currentHour >= EndHour) {
      info += "Di luar jam trading yang ditentukan: "+ currentHour + ":00\n";
      return;
   }

   string symbol = _Symbol;

   // --- Data H1
   double highH1 = iHigh(symbol, TimeframeH1, iHighest(symbol, TimeframeH1, MODE_HIGH, 60, 0));
   double lowH1 = iLow(symbol, TimeframeH1, iLowest(symbol, TimeframeH1, MODE_LOW, 60, 0));
   double middleH1 = GetMiddle(highH1, lowH1);
   double priceH1 = iClose(symbol, TimeframeH1, 0);

   // --- Bollinger Bands M5
   int bbHandle2 = iBands(symbol, TimeframeM5, 20, 2, 0, PRICE_CLOSE);
   int bbHandle3 = iBands(symbol, TimeframeM5, 20, 3, 0, PRICE_CLOSE);

   double bbUpper2[], bbLower2[];
   double bbUpper3[], bbLower3[];

   CopyBuffer(bbHandle2, 0, 0, 2, bbUpper2); // Upper band = buffer 0
   CopyBuffer(bbHandle2, 2, 0, 2, bbLower2); // Lower band = buffer 2

   CopyBuffer(bbHandle3, 0, 0, 2, bbUpper3); // Upper band = buffer 0
   CopyBuffer(bbHandle3, 2, 0, 2, bbLower3); // Lower band = buffer 2

   // Ambil nilai terbaru
   double upper2_now = bbUpper2[0];
   double lower2_now = bbLower2[0];
   double upper3_now = bbUpper3[0];
   double lower3_now = bbLower3[0];

   // --- Moving Average M5 (perbaikan parameter)
   double maCurrent = 100;
   double maPrev = 200;

   // --- RSI M5
   int rsiHandle = iRSI(symbol, TimeframeM5, 14, PRICE_CLOSE);
   double rsiBuffer[];
   double rsiCurrent = 0, rsiPrev = 0;
   if (CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer) > 0) {
       rsiCurrent = rsiBuffer[0];
       rsiPrev = rsiBuffer[1];
   } else {
       info += "Gagal membaca RSI\n\n";
   }

   // --- Momentum M5
   int momM5Handle = iMomentum(symbol, TimeframeM5, 14, PRICE_CLOSE);
   double momM5Buffer[];
   double momM5 = 0, momM5_prev = 0;
   if (CopyBuffer(momM5Handle, 0, 0, 2, momM5Buffer) > 0) {
       momM5 = momM5Buffer[0];
       momM5_prev = momM5Buffer[1];
   }

   // --- Info akun
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);

   // --- Cetak indikator
   info += "==== TRANSKSI ====\n";
   info +="Tinggi: "+ highH1 / _Point + "\nRendah: "+ lowH1 / _Point + "\nTengah: "+ middleH1+ " \nHarga: "+ priceH1 + "\n";
   
   info += "\n\n==== BOLINGER BAND ====\n";
   info +="BB2 U/L: "+ upper2_now+"/"+ lower2_now+ " | BB3 U/L: "+ upper3_now+ "/"+ lower3_now +"\n";
   
   info += "\n\n==== MOVING AVERAGE ====\n";
   info +="MA Sekarang: "+ maCurrent + "\n" ;
   info += "MA Tadi: "+ maPrev +"\n";
   if(maCurrent>maPrev){
      info +="Kesimpulan: Naik\n";
   }else{
      info +="Kesimpulan: Turun\n";
   }
   
   info += "\n\n==== RSI====\n";
   info +="RSI Sekarang: "+ rsiCurrent+"\n";
   info +="RSI Tadi: "+ rsiPrev +"\n";
   if(rsiCurrent>rsiPrev){
      info +="Kesimpulan: Naik\n";
   }else{
      info +="Kesimpulan: Turun\n";
   }
   
   
   info += "\n\n==== MOMENTUM ====\n";
   info +="Momentum Sekarang: "+  momM5 / _Point +"\n";
   info +="Momentum Tadi: "+ momM5_prev / _Point + "\n";
   if(momM5>momM5_prev){
      info +="Kesimpulan: Naik\n";
   }else{
      info +="Kesimpulan: Turun\n";
   }

   // --- Sinyal BUY
   bool buySignal = (
      priceH1 < middleH1 &&
      upper3_now > upper2_now && lower3_now > lower2_now &&
      (maCurrent < maPrev || maCurrent > lower2_now) &&
      (rsiCurrent < 50 || rsiCurrent > rsiPrev) &&
      momM5 > momM5_prev
   );

   // --- Sinyal SELL
   bool sellSignal = (
      priceH1 > middleH1 &&
      upper2_now < upper3_now && lower2_now < lower3_now &&
      (maCurrent > maPrev || maCurrent < upper2_now) &&
      (rsiCurrent > 50 || rsiCurrent < rsiPrev) &&
      momM5 < momM5_prev
   );

   string status = "Status: Tidak Ada Sinyal\n\n";

   // --- Eksekusi order jika belum ada posisi
   if (!IsPositionOpen(symbol)) {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

      if (buySignal) {
         double sl = ask - StopLossPoints * _Point;
         double tp = ask + TakeProfitPoints * _Point;
         if (trade.Buy(LotSize, symbol, ask, sl, tp, "Buy signal")) {
            status = "BUY dieksekusi\n\n";
         }
      } else if (sellSignal) {
         double sl = bid + StopLossPoints * _Point;
         double tp = bid - TakeProfitPoints * _Point;
         if (trade.Sell(LotSize, symbol, bid, sl, tp, "Sell signal")) {
            status = "SELL dieksekusi\n\n";
         }
      }
   } else {
      status = "Posisi masih terbuka. Tidak membuka posisi baru.\n\n";
   }

   // --- Cetak status akun dan kesimpulan
   info += "\n\n==== STATUS ====\n";
   info += status;
   info +="Saldo: "+ balance+ ", Ekuitas: "+ equity+ ", Profit/Rugi: "+ profit;
   Comment(info);
}
