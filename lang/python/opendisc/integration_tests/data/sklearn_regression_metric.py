from opendisc.api import read_data
from sklearn.linear_model import LinearRegression
import sklearn.metrics

diabetes_path = str(data_path.joinpath('diabetes.csv'))
diabetes = read_data(diabetes_path)

X = diabetes.drop('y', 1)
y = diabetes['y']
lm = LinearRegression()
lm.fit(X, y)

y_hat = lm.predict(X)
l1_err = sklearn.metrics.mean_absolute_error(y, y_hat)
l2_err = sklearn.metrics.mean_squared_error(y, y_hat)
