callfromUI = function(MovieIDList, ratingList){
  # get ratings
  myurl = "https://liangfgithub.github.io/MovieData/"
  ratings = read.csv(paste0(myurl, 'ratings.dat?raw=true'), 
                     sep = ':',
                     colClasses = c('integer', 'NULL'), 
                     header = FALSE)
  colnames(ratings) = c('UserID', 'MovieID', 'Rating', 'Timestamp')
  # filter ratings_per_movie > 500 and ratings_per_user >100 to get ratings_new
  popMovie = ratings %>% 
    group_by(MovieID) %>% 
    summarize(ratings_per_movie = n(), ave_ratings = mean(Rating)) %>%
    inner_join(movies, by = 'MovieID') %>% 
    filter(ratings_per_movie > 500)
  popID = popMovie %>% select(MovieID)
  freqUser = ratings %>% 
    inner_join(popID, by = 'MovieID')  %>% 
    group_by(UserID) %>% 
    summarize(ratings_per_user = n()) %>% 
    filter(ratings_per_user >100) 
  freqID = freqUser %>%  select(UserID)
  ratings_new = ratings %>% 
    inner_join(freqID, by = 'UserID')%>% 
    inner_join(popID, by = 'MovieID')
  # build the training matrix
  i = paste0('u', ratings_new$UserID)
  j = paste0('m', ratings_new$MovieID)
  x = ratings_new$Rating
  tmp = data.frame(i, j, x, stringsAsFactors = T)
  Rmatrix = sparseMatrix(as.integer(tmp$i), as.integer(tmp$j), x = tmp$x)
  rownames(Rmatrix) = levels(tmp$i)
  colnames(Rmatrix) = levels(tmp$j)
  Rmatrix = new('realRatingMatrix', data = Rmatrix)
  # traing model
  rec_UBCF = Recommender(Rmatrix, method = 'UBCF',
                         parameter = list(normalize = 'Z-score', method = 'pearson', nn = 150))
  rec_SVDF = Recommender(Rmatrix, method = 'SVDF',parameter = list(normalize = 'Z-score', k = 9))
  # new user
  n.item = ncol(Rmatrix) 
  new.ratings = rep(NA, n.item)  
  #MovieIDList = c(1,10,1019,1022)
  #ratingList = c(4,4,4,4)
  for (i in 1:length(MovieIDList)){
    mid = paste("m", MovieIDList[i], sep='')
    index = match(mid,colnames(Rmatrix))
    new.ratings[index] = ratingList[index]
  }
  new.user = matrix(new.ratings, 
                    nrow=1, ncol=n.item,
                    dimnames = list(
                      user=paste('newUser'),
                      item=colnames(Rmatrix)
                    ))
  new.Rmat = as(new.user, 'realRatingMatrix')
  # prediction
  recom = predict(rec_SVDF, new.Rmat, type = 'ratings')
  #as(recom, 'matrix')
  recom_results = data.frame(mID=dimnames(recom)[[2]],pred_ratings=as.vector(as(recom, 'matrix')))
  recom_results = recom_results[order(recom_results$pred_ratings, decreasing=TRUE),]
  rec_10 =  as.character(recom_results$mID[1:10])
  rec_10 = as.numeric(sub("m", "", rec_10))
  return(rec_10)
}
